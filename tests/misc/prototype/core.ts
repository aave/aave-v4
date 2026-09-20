import * as U from './utils';
const {
  DEBUG, MAX_UINT, assertNonZero, absDiff, randomRiskPremium, randomIndex,
  f, formatBps, info, rayMulUp, rayMulDown, rayDivUp, rayDivDown, fromRayUp,
  toRay, percentMulUp, percentMulDown, calculatePremiumRay, signedSub,
  addSigned, toSharesDown, toSharesUp, toAssetsDown, toAssetsUp,
  RAY, PRECISION, VIRTUAL_ASSETS, VIRTUAL_SHARES, maxAbsDiff, randomAmount,
  formatUnits, min,
} = U;
type PremiumDelta = U.PremiumDelta;

let spokeIdCounter = 0n;
let userIdCounter = 0n;

let currentTime = 1n;

export class Hub {
  public spokes: Spoke[] = [];
  public lastUpdateTimestamp = 0n;

  public drawnShares = 0n;
  public premiumShares = 0n;
  public premiumOffsetRay = 0n; // signed bigint (can be negative)

  public drawnIndex = RAY;
  private _pendingIndex = RAY;
  private _pendingIndexTimestamp = 0n;

  public liquidity = 0n;
  public swept = 0n;
  public deficitRay = 0n;

  public addedShares = 0n;

  public realizedFees = 0n;
  public liquidityFee = 0n; // BPS (0-10000)

  toDrawnAssetsUp(shares: bigint): bigint {
    return rayMulUp(shares, this.getDrawnIndex());
  }

  toDrawnAssetsDown(shares: bigint): bigint {
    return rayMulDown(shares, this.getDrawnIndex());
  }

  toDrawnSharesUp(assets: bigint): bigint {
    return rayDivUp(assets, this.getDrawnIndex());
  }

  toDrawnSharesDown(assets: bigint): bigint {
    return rayDivDown(assets, this.getDrawnIndex());
  }

  drawnDebt(): bigint {
    return this.toDrawnAssetsUp(this.drawnShares);
  }

  premiumRay(): bigint {
    return calculatePremiumRay(this.premiumShares, this.premiumOffsetRay, this.getDrawnIndex());
  }

  premiumDebt(): bigint {
    return fromRayUp(this.premiumRay());
  }

  calculateAggregatedOwedRay(drawnIndex: bigint): bigint {
    const premRay = calculatePremiumRay(this.premiumShares, this.premiumOffsetRay, drawnIndex);
    return this.drawnShares * drawnIndex + premRay + this.deficitRay;
  }

  calculateAggregatedOwedRayAt(drawnIndex: bigint): bigint {
    const premRay = calculatePremiumRay(this.premiumShares, this.premiumOffsetRay, drawnIndex);
    return this.drawnShares * drawnIndex + premRay + this.deficitRay;
  }


  getUnrealizedFees(newDrawnIndex: bigint): bigint {
    const previousIndex = this.drawnIndex;
    if (previousIndex === newDrawnIndex) return 0n;
    if (this.liquidityFee === 0n) return 0n;

    const owedRayAfter = this.calculateAggregatedOwedRayAt(newDrawnIndex);
    const owedRayBefore = this.calculateAggregatedOwedRayAt(previousIndex);

    return percentMulDown(fromRayUp(owedRayAfter) - fromRayUp(owedRayBefore), this.liquidityFee);
  }


  totalAddedAssets(): bigint {
    const drawnIdx = this.getDrawnIndex();
    const aggregatedOwedRay = this.calculateAggregatedOwedRay(drawnIdx);
    return (
      this.liquidity +
      this.swept +
      fromRayUp(aggregatedOwedRay) -
      this.realizedFees -
      this.getUnrealizedFees(drawnIdx)
    );
  }

  toAddedAssetsDown(shares: bigint): bigint {
    return toAssetsDown(shares, this.totalAddedAssets(), this.addedShares);
  }

  toAddedAssetsUp(shares: bigint): bigint {
    return toAssetsUp(shares, this.totalAddedAssets(), this.addedShares);
  }

  toAddedSharesDown(assets: bigint): bigint {
    return toSharesDown(assets, this.totalAddedAssets(), this.addedShares);
  }

  toAddedSharesUp(assets: bigint): bigint {
    return toSharesUp(assets, this.totalAddedAssets(), this.addedShares);
  }

  getDrawnIndex(): bigint {
    if (
      this.lastUpdateTimestamp === currentTime ||
      (this.drawnShares === 0n && this.premiumShares === 0n)
    ) {
      return this.drawnIndex;
    }
    if (this._pendingIndexTimestamp !== currentTime) {
      this._pendingIndex = rayMulUp(this.drawnIndex, randomIndex());
      this._pendingIndexTimestamp = currentTime;
    }
    return this._pendingIndex;
  }


  accrue() {
    if (this.lastUpdateTimestamp === currentTime) return;

    const newDrawnIndex = this.getDrawnIndex();
    this.realizedFees += this.getUnrealizedFees(newDrawnIndex);
    this.drawnIndex = newDrawnIndex;
    this.lastUpdateTimestamp = currentTime;
  }

  add(amount: bigint, spoke: Spoke): bigint {
    const shares = this.toAddedSharesDown(amount);
    assertNonZero(shares);

    this.addedShares += shares;
    this.liquidity += amount;

    this.getSpoke(spoke).addedShares += shares;

    return shares;
  }


  remove(amount: bigint, spoke: Spoke): bigint {
    const shares = this.toAddedSharesUp(amount);

    this.addedShares -= shares;
    this.liquidity -= amount;

    this.getSpoke(spoke).addedShares -= shares;

    Utils.checkBounds(this);
    return shares;
  }


  draw(amount: bigint, spoke: Spoke): bigint {
    if (amount > this.liquidity) throw new Error('InsufficientLiquidity');
    const drawnShares = this.toDrawnSharesUp(amount);

    this.liquidity -= amount;
    this.drawnShares += drawnShares;

    this.getSpoke(spoke).drawnShares += drawnShares;

    return drawnShares;
  }


  restore(drawnAmount: bigint, premiumDelta: PremiumDelta, spoke: Spoke): bigint {
    const drawnShares = this.toDrawnSharesDown(drawnAmount);

    this.drawnShares -= drawnShares;
    this.getSpoke(spoke).drawnShares -= drawnShares;

    this.applyPremiumDelta(premiumDelta, spoke);

    const premiumAmount = fromRayUp(premiumDelta.restoredPremiumRay);
    this.liquidity += drawnAmount + premiumAmount;

    return drawnShares;
  }


  refreshPremium(premiumDelta: PremiumDelta, spoke: Spoke) {
    if (premiumDelta.restoredPremiumRay !== 0n) {
      throw new Error('refreshPremium: restoredPremiumRay must be 0');
    }
    this.applyPremiumDelta(premiumDelta, spoke);
  }


  reportDeficit(drawnAmount: bigint, premiumDelta: PremiumDelta, spoke: Spoke): bigint {
    const drawnShares = this.toDrawnSharesDown(drawnAmount);
    const spokeData = this.getSpoke(spoke);

    this.drawnShares -= drawnShares;
    spokeData.drawnShares -= drawnShares;

    this.applyPremiumDelta(premiumDelta, spoke);

    const deficitAmountRay = drawnShares * this.drawnIndex + premiumDelta.restoredPremiumRay;
    this.deficitRay += deficitAmountRay;
    spokeData.deficitRay += deficitAmountRay;

    return drawnShares;
  }


  eliminateDeficit(amount: bigint, callerSpoke: Spoke, coveredSpoke: Spoke): bigint {
    this.accrue();
    const callerData = this.getSpoke(callerSpoke);
    const coveredData = this.getSpoke(coveredSpoke);

    const defRay = coveredData.deficitRay;
    const deficitAmountRay = amount < fromRayUp(defRay) ? toRay(amount) : defRay;

    const shares = this.toAddedSharesUp(fromRayUp(deficitAmountRay));
    this.addedShares -= shares;
    callerData.addedShares -= shares;
    this.deficitRay -= deficitAmountRay;
    coveredData.deficitRay -= deficitAmountRay;

    return shares;
  }


  applyPremiumDelta(premiumDelta: PremiumDelta, spoke: Spoke) {
    const drawnIndex = this.drawnIndex;

    [this.premiumShares, this.premiumOffsetRay] = this.validateApplyPremiumDelta(
      drawnIndex,
      this.premiumShares,
      this.premiumOffsetRay,
      premiumDelta
    );

    const spokeData = this.getSpoke(spoke);
    [spokeData.premiumShares, spokeData.premiumOffsetRay] = this.validateApplyPremiumDelta(
      drawnIndex,
      spokeData.premiumShares,
      spokeData.premiumOffsetRay,
      premiumDelta
    );
  }


  validateApplyPremiumDelta(
    drawnIndex: bigint,
    premiumShares: bigint,
    premiumOffsetRay: bigint,
    premiumDelta: PremiumDelta
  ): [bigint, bigint] {
    const premiumRayBefore = calculatePremiumRay(premiumShares, premiumOffsetRay, drawnIndex);

    const newPremiumShares = addSigned(premiumShares, premiumDelta.sharesDelta);
    const newPremiumOffsetRay = premiumOffsetRay + premiumDelta.offsetRayDelta;

    const premiumRayAfter = calculatePremiumRay(newPremiumShares, newPremiumOffsetRay, drawnIndex);

    if (premiumRayAfter + premiumDelta.restoredPremiumRay !== premiumRayBefore) {
      throw new Error(
        `validateApplyPremiumDelta: invariant failed. ` +
          `after(${premiumRayAfter}) + restored(${premiumDelta.restoredPremiumRay}) != before(${premiumRayBefore})`
      );
    }
    return [newPremiumShares, newPremiumOffsetRay];
  }

  getTotalDebt(): bigint {
    const d = this.getDebt();
    return d.drawnDebt + d.premiumDebt;
  }

  getDebt() {
    this.accrue();
    const drawnIdx = this.drawnIndex;
    return {
      drawnDebt: rayMulUp(this.drawnShares, drawnIdx),
      premiumDebt: fromRayUp(calculatePremiumRay(this.premiumShares, this.premiumOffsetRay, drawnIdx)),
    };
  }

  convertToAddedAssets(shares: bigint): bigint {
    return this.toAddedAssetsDown(shares);
  }
  convertToAddedShares(assets: bigint): bigint {
    return this.toAddedSharesDown(assets);
  }
  convertToDrawnAssets(shares: bigint): bigint {
    return this.toDrawnAssetsUp(shares);
  }
  convertToDrawnShares(assets: bigint): bigint {
    return this.toDrawnSharesDown(assets);
  }

  supplyExchangeRatio() {
    return {
      totalAddedAssets: this.totalAddedAssets(),
      totalAddedShares: this.addedShares,
    };
  }

  getSpoke(spoke: Spoke) {
    return this.spokes[this.idx(spoke)];
  }

  idx(spoke: Spoke) {
    const idx = this.spokes.findIndex((s) => s.id === spoke.id);
    if (idx === -1) {
      this.addSpoke(spoke);
      return this.spokes.length - 1;
    }
    return idx;
  }

  addSpoke(who: Spoke) {
    this.spokes.push(new Spoke(this, who.id));
  }

  log(spokes = false, users = false) {
    const premRay = calculatePremiumRay(this.premiumShares, this.premiumOffsetRay, this.drawnIndex);
    console.log('--- Hub ---');
    console.log('hub.drawnShares          ', f(this.drawnShares));
    console.log('hub.premiumShares        ', f(this.premiumShares));
    console.log('hub.premiumOffsetRay     ', this.premiumOffsetRay);
    console.log('hub.premiumRay           ', premRay);
    console.log('hub.premiumDebt          ', f(fromRayUp(premRay)));
    console.log('hub.addedShares          ', f(this.addedShares));
    console.log('hub.totalAddedAssets     ', f(this.totalAddedAssets()));
    console.log('hub.liquidity            ', f(this.liquidity));
    console.log('hub.drawnDebt            ', f(this.drawnDebt()));
    console.log('hub.premiumDebt()        ', f(this.premiumDebt()));
    console.log('hub.deficitRay           ', this.deficitRay);
    console.log('hub.realizedFees         ', f(this.realizedFees));
    console.log('hub.liquidityFee         ', this.liquidityFee);
    console.log('hub.drawnIndex           ', this.drawnIndex);
    console.log('hub.lastUpdateTimestamp   ', this.lastUpdateTimestamp);
    console.log('hub.getTotalDebt         ', f(this.getTotalDebt()));
    console.log('hub.getDebt: drawnDebt   ', f(this.getDebt().drawnDebt));
    console.log('hub.getDebt: premiumDebt ', f(this.getDebt().premiumDebt));
    console.log();

    if (spokes) this.spokes.forEach((spoke) => spoke.log(false, users));
  }

  whoami() {
    return 'Hub';
  }
}

export class Spoke {
  public users: User[] = [];

  public drawnShares = 0n;
  public premiumShares = 0n;
  public premiumOffsetRay = 0n; // signed
  public addedShares = 0n;
  public deficitRay = 0n;

  constructor(
    public hub: Hub,
    public readonly id = ++spokeIdCounter
  ) {}

  supply(amount: bigint, who: User): bigint {
    const user = this.getUser(who);
    this.hub.accrue();
    const shares = this.hub.add(amount, this);

    this.addedShares += shares;
    user.addedShares += shares;

    this.refreshUserPremium(user);

    return shares;
  }

  withdraw(amount: bigint, who: User): bigint {
    const user = this.getUser(who);
    this.hub.accrue();
    amount = min(amount, min(user.getSuppliedBalance(), this.hub.liquidity));
    if (amount === 0n) return 0n;

    let shares = this.hub.toAddedSharesUp(amount);
    shares = min(shares, user.addedShares);

    this.hub.addedShares -= shares;
    this.hub.liquidity -= amount;
    this.hub.getSpoke(this).addedShares -= shares;

    this.addedShares -= shares;
    user.addedShares -= shares;

    this.refreshUserPremium(user);

    return shares;
  }

  borrow(amount: bigint, who: User): bigint {
    const user = this.getUser(who);
    this.hub.accrue();
    const drawnIndex = this.hub.drawnIndex;

    const drawnShares = this.hub.draw(amount, this);
    this.drawnShares += drawnShares;
    user.drawnShares += drawnShares;

    const newRiskPremium = randomRiskPremium();
    user.riskPremium = newRiskPremium;

    const premiumDelta = this.calculatePremiumDelta(user, 0n, drawnIndex, newRiskPremium, 0n);

    this.hub.refreshPremium(premiumDelta, this);
    this.applyLocalPremiumDelta(premiumDelta);
    this.applyUserPremiumDelta(user, premiumDelta);

    return drawnShares;
  }

  repay(amount: bigint, who: User): [bigint, bigint] {
    const user = this.getUser(who);
    this.hub.accrue();
    const drawnIndex = this.hub.drawnIndex;

    const {drawnDebtRestored, premiumDebtRayRestored} = this.calculateRestoreAmount(
      user,
      drawnIndex,
      amount
    );

    const restoredShares = rayDivDown(drawnDebtRestored, drawnIndex);

    const premiumDelta = this.calculatePremiumDelta(
      user,
      restoredShares,
      drawnIndex,
      user.riskPremium,
      premiumDebtRayRestored
    );

    const drawnSharesRestored = this.hub.restore(drawnDebtRestored, premiumDelta, this);

    this.applyLocalPremiumDelta(premiumDelta);
    this.applyUserPremiumDelta(user, premiumDelta);

    this.drawnShares -= drawnSharesRestored;
    user.drawnShares -= drawnSharesRestored;

    const premiumAmountRestored = fromRayUp(premiumDebtRayRestored);
    return [drawnSharesRestored, premiumAmountRestored];
  }


  calculatePremiumDelta(
    user: User,
    drawnSharesTaken: bigint,
    drawnIndex: bigint,
    riskPremium: bigint,
    restoredPremiumRay: bigint
  ): PremiumDelta {
    const oldPremiumShares = user.premiumShares;
    const oldPremiumOffsetRay = user.premiumOffsetRay;
    const premiumDebtRay = calculatePremiumRay(oldPremiumShares, oldPremiumOffsetRay, drawnIndex);

    const newPremiumShares = percentMulUp(user.drawnShares - drawnSharesTaken, riskPremium);
    const newPremiumOffsetRay = signedSub(
      newPremiumShares * drawnIndex,
      premiumDebtRay - restoredPremiumRay
    );

    return {
      sharesDelta: signedSub(newPremiumShares, oldPremiumShares),
      offsetRayDelta: newPremiumOffsetRay - oldPremiumOffsetRay,
      restoredPremiumRay,
    };
  }


  calculateRestoreAmount(
    user: User,
    drawnIndex: bigint,
    amount: bigint
  ): {drawnDebtRestored: bigint; premiumDebtRayRestored: bigint} {
    const drawnDebt = rayMulUp(user.drawnShares, drawnIndex);
    const premiumDebtRay = calculatePremiumRay(
      user.premiumShares,
      user.premiumOffsetRay,
      drawnIndex
    );
    const premiumDebt = fromRayUp(premiumDebtRay);

    if (amount >= drawnDebt + premiumDebt || amount === MAX_UINT) {
      return {drawnDebtRestored: drawnDebt, premiumDebtRayRestored: premiumDebtRay};
    }

    if (amount < premiumDebt) {
      return {drawnDebtRestored: 0n, premiumDebtRayRestored: toRay(amount)};
    }

    return {drawnDebtRestored: amount - premiumDebt, premiumDebtRayRestored: premiumDebtRay};
  }

  applyLocalPremiumDelta(premiumDelta: PremiumDelta) {
    this.premiumShares = addSigned(this.premiumShares, premiumDelta.sharesDelta);
    this.premiumOffsetRay = this.premiumOffsetRay + premiumDelta.offsetRayDelta;
  }


  applyUserPremiumDelta(user: User, premiumDelta: PremiumDelta) {
    user.premiumShares = addSigned(user.premiumShares, premiumDelta.sharesDelta);
    user.premiumOffsetRay = user.premiumOffsetRay + premiumDelta.offsetRayDelta;
  }

  refreshUserPremium(who: User) {
    const user = this.getUser(who);
    if (user.drawnShares === 0n) return;

    this.hub.accrue();
    const newRiskPremium = randomRiskPremium();
    user.riskPremium = newRiskPremium;
    const drawnIndex = this.hub.drawnIndex;

    const premiumDelta = this.calculatePremiumDelta(user, 0n, drawnIndex, newRiskPremium, 0n);

    this.hub.refreshPremium(premiumDelta, this);
    this.applyLocalPremiumDelta(premiumDelta);
    this.applyUserPremiumDelta(user, premiumDelta);
  }

  getTotalDebt(): bigint {
    const d = this.getDebt();
    return d.drawnDebt + d.premiumDebt;
  }

  getDebt() {
    this.hub.accrue();
    const drawnIdx = this.hub.drawnIndex;
    return {
      drawnDebt: rayMulUp(this.drawnShares, drawnIdx),
      premiumDebt: fromRayUp(
        calculatePremiumRay(this.premiumShares, this.premiumOffsetRay, drawnIdx)
      ),
    };
  }

  getUserDebt(who: User) {
    this.hub.accrue();
    const user = this.getUser(who);
    const drawnIdx = this.hub.drawnIndex;
    return {
      drawnDebt: rayMulUp(user.drawnShares, drawnIdx),
      premiumDebt: fromRayUp(
        calculatePremiumRay(user.premiumShares, user.premiumOffsetRay, drawnIdx)
      ),
    };
  }

  getUserTotalDebt(who: User): bigint {
    const d = this.getUserDebt(who);
    return d.drawnDebt + d.premiumDebt;
  }

  addUser(user: User) {
    this.users.push(user);
    user.assignSpoke(this);
  }

  getUser(user: User | number) {
    if (typeof user === 'number') return this.users[user];
    return this.users[this.userIdx(user)];
  }

  userIdx(user: User) {
    const idx = this.users.findIndex((s) => s.id === user.id);
    if (idx === -1) {
      this.addUser(user);
      user.assignSpoke(this);
      return this.users.length - 1;
    }
    return idx;
  }

  log(hub = false, users = false) {
    const drawnIdx = this.hub.drawnIndex;
    const premRay = calculatePremiumRay(this.premiumShares, this.premiumOffsetRay, drawnIdx);
    console.log(`--- Spoke ${this.id} ---`);
    console.log('spoke.drawnShares        ', f(this.drawnShares));
    console.log('spoke.premiumShares      ', f(this.premiumShares));
    console.log('spoke.premiumOffsetRay   ', this.premiumOffsetRay);
    console.log('spoke.premiumDebt        ', f(fromRayUp(premRay)));
    console.log('spoke.addedShares        ', f(this.addedShares));
    console.log('spoke.deficitRay         ', this.deficitRay);
    console.log('spoke.getTotalDebt       ', f(this.getTotalDebt()));
    console.log('spoke.getDebt: drawnDebt ', f(this.getDebt().drawnDebt));
    console.log('spoke.getDebt: premDebt  ', f(this.getDebt().premiumDebt));
    console.log();
    if (hub) this.hub.log();
    if (users) this.users.forEach((user) => user.log());
  }

  whoami() {
    return `Spoke ${this.id}`;
  }
}

export class User {
  public spoke!: Spoke;
  public hub!: Hub;

  public drawnShares = 0n;
  public premiumShares = 0n;
  public premiumOffsetRay = 0n; // signed
  public addedShares = 0n;

  constructor(
    public readonly id = ++userIdCounter,
    public riskPremium = randomRiskPremium(),
    spoke: Spoke | null = null
  ) {
    if (spoke) this.assignSpoke(spoke);
  }

  supply(amount: bigint) {
    this.beforeHook('supply', amount);
    const shares = this.spoke.supply(amount, this);
    this.afterHook();
    return shares;
  }

  withdraw(amount: bigint) {
    this.beforeHook('withdraw', amount);
    const shares = this.spoke.withdraw(amount, this);
    this.afterHook();
    return shares;
  }

  borrow(amount: bigint) {
    this.beforeHook('borrow', amount);
    const drawnShares = this.spoke.borrow(amount, this);
    this.afterHook();
    return drawnShares;
  }

  repay(amount: bigint) {
    this.beforeHook('repay', amount);
    const [drawnDebtSharesRestored, premiumAmountRestored] = this.spoke.repay(amount, this);
    this.afterHook();
    return [drawnDebtSharesRestored, premiumAmountRestored];
  }

  updateRiskPremium() {
    this.beforeHook('updateRiskPremium');
    this.spoke.refreshUserPremium(this);
    this.afterHook();
  }

  assignSpoke(spoke: Spoke) {
    this.spoke = spoke;
    this.hub = spoke.hub;
  }

  getDebt() {
    return this.spoke.getUserDebt(this);
  }

  getTotalDebt() {
    return this.spoke.getUserTotalDebt(this);
  }

  getSuppliedBalance() {
    return this.hub.convertToAddedAssets(this.addedShares);
  }

  log(spoke = false, hub = false) {
    const drawnIdx = this.hub.drawnIndex;
    const premRay = calculatePremiumRay(this.premiumShares, this.premiumOffsetRay, drawnIdx);
    console.log(`--- User ${this.id} ---`);
    console.log('user.drawnShares         ', f(this.drawnShares));
    console.log('user.premiumShares       ', f(this.premiumShares));
    console.log('user.premiumOffsetRay    ', this.premiumOffsetRay);
    console.log('user.premiumDebt         ', f(fromRayUp(premRay)));
    console.log('user.addedShares         ', f(this.addedShares));
    console.log('user.riskPremium         ', formatBps(this.riskPremium));
    console.log('user.getTotalDebt        ', f(this.spoke.getUserTotalDebt(this)));
    console.log('user.getDebt: drawnDebt  ', f(this.spoke.getUserDebt(this).drawnDebt));
    console.log('user.getDebt: premDebt   ', f(this.spoke.getUserDebt(this).premiumDebt));
    console.log();
    if (spoke) this.spoke.log();
    if (hub) this.hub.log();
  }

  whoami() {
    return `User ${this.id}`;
  }

  beforeHook(action: string, amount?: bigint) {
    this.logAction(action, amount);
  }
  afterHook() {}

  logAction(action: string, amount?: bigint) {
    info(`action ${action}, id ${this.id}`, amount && `amount ${f(amount)}`);
  }
}

export class System {
  public hub: Hub;
  public spokes: Spoke[];
  public users: User[];

  public supplyExchangeRatio!: ReturnType<typeof Hub.prototype.supplyExchangeRatio>;

  constructor(numSpokes = 1, numUsers = 3) {
    this.hub = new Hub();
    this.spokes = new Array(numSpokes).fill(null).map(() => new Spoke(this.hub));
    this.users = new Array(numUsers).fill(null).map(() => new User());
    this.assignSpokes();
    this.setHooks();
  }

  assignSpokes() {
    this.users.forEach((user) => {
      const spoke = this.spokes[Math.floor(Math.random() * this.spokes.length)];
      user.assignSpoke(spoke);
      spoke.addUser(user);
    });
  }

  setHooks() {
    this.users.forEach((user) => {
      user.beforeHook = (action: string, amount?: bigint) => {
        user.logAction(action, amount);
        console.log(
          'debt ex ratio before',
          formatUnits(this.hub.convertToDrawnAssets(10n ** 50n), 50)
        );
        this.supplyExchangeRatio = this.hub.supplyExchangeRatio();
      };
      user.afterHook = () => {
        this.invariant_supplyExchangeRateIsNonDecreasing();
        this.runInvariants();
      };
    });
  }

  nonZeroAddedShares(amount: bigint) {
    while (this.hub.convertToAddedShares(amount) === 0n) amount = randomAmount();
    return amount;
  }

  repayAll() {
    this.users.forEach((user) => user.getTotalDebt() && user.repay(MAX_UINT));
    this.runInvariants();
  }
  withdrawAll() {
    this.users.forEach((user) => user.getSuppliedBalance() && user.withdraw(MAX_UINT));
    this.runInvariants();
  }

  runInvariants() {
    this.invariant_valuesWithinBounds();
    this.invariant_hubSpokeAccounting();
    this.invariant_sumOfDrawnDebt();
    this.invariant_sumOfPremiumDebt();
    this.invariant_sumOfAddedShares();
    this.invariant_sumOfDeficitRay();
  }

  invariant_valuesWithinBounds() {
    let fail = false;
    const all: (Hub | Spoke | User)[] = [this.hub, ...this.spokes, ...this.users];

    // Non-negative unsigned fields
    ['drawnShares', 'premiumShares', 'addedShares'].forEach((key) => {
      all.forEach((who) => {
        if ((who as any)[key] < 0n || (who as any)[key] > MAX_UINT) {
          who.log(who instanceof User, who instanceof User);
          console.error(`${who.whoami()}.${key} out of bounds`, f((who as any)[key]));
          fail = true;
        }
      });
    });

    // Premium must be non-negative (calculatePremiumRay validates)
    const drawnIdx = this.hub.drawnIndex;
    all.forEach((who) => {
      try {
        calculatePremiumRay(who.premiumShares, who.premiumOffsetRay, drawnIdx);
      } catch (e) {
        who.log();
        console.error(`${who.whoami()} has negative premium`);
        fail = true;
      }
    });

    // Hub-specific bounds
    if (this.hub.liquidity < 0n) {
      console.error('hub.liquidity < 0');
      fail = true;
    }

    this.handleFailure(fail, 'invariant_valuesWithinBounds');
  }

  invariant_sumOfDrawnDebt() {
    let fail = false,
      diff = 0n;
    const hubDrawnDebt = this.hub.getDebt().drawnDebt;
    const spokeDrawn = this.spokes.reduce((sum, spoke) => sum + spoke.getDebt().drawnDebt, 0n);
    const userDrawnDebt = this.users.reduce((sum, user) => sum + user.getDebt().drawnDebt, 0n);
    if ((diff = absDiff(hubDrawnDebt, spokeDrawn)) > PRECISION) {
      console.error('hubDrawnDebt !== spokeDrawn, diff', f(hubDrawnDebt), f(spokeDrawn), diff);
      fail = true;
    }
    if ((diff = absDiff(spokeDrawn, userDrawnDebt)) > PRECISION) {
      console.error('spokeDrawn !== userDrawnDebt, diff', f(spokeDrawn), f(userDrawnDebt), diff);
      fail = true;
    }
    if ((diff = maxAbsDiff(hubDrawnDebt, spokeDrawn, userDrawnDebt)) > PRECISION) {
      console.error(
        'maxAbsDiff(hubDrawnDebt, spokeDrawn, userDrawnDebt) > PRECISION',
        f(hubDrawnDebt),
        f(spokeDrawn),
        f(userDrawnDebt),
        diff
      );
      fail = true;
    }

    if (hubDrawnDebt === 0n && spokeDrawn + userDrawnDebt !== 0n) {
      console.error(
        'spoke & user dust drawnDebt remaining when hub drawnDebt is completely repaid',
        f(spokeDrawn),
        f(userDrawnDebt)
      );
      fail = true;
    }

    this.handleFailure(fail, 'invariant_sumOfDrawnDebt');
  }

  invariant_sumOfPremiumDebt() {
    let fail = false,
      diff = 0n;
    const hubPremiumDebt = this.hub.getDebt().premiumDebt;
    const spokePremium = this.spokes.reduce(
      (sum, spoke) => sum + spoke.getDebt().premiumDebt,
      0n
    );
    const userPremiumDebt = this.users.reduce(
      (sum, user) => sum + user.getDebt().premiumDebt,
      0n
    );
    if ((diff = absDiff(hubPremiumDebt, spokePremium)) > PRECISION) {
      console.error(
        'hubPremiumDebt !== spokePremium, diff',
        f(hubPremiumDebt),
        f(spokePremium),
        diff
      );
      fail = true;
    }
    if ((diff = absDiff(spokePremium, userPremiumDebt)) > PRECISION) {
      console.error(
        'spokePremium !== userPremiumDebt, diff',
        f(spokePremium),
        f(userPremiumDebt),
        diff
      );
      fail = true;
    }

    // Validate internal premium vars sum correctly
    // premiumShares: exact match
    const hubPS = this.hub.premiumShares;
    const spokePS = this.spokes.reduce((sum, spoke) => sum + spoke.premiumShares, 0n);
    const userPS = this.users.reduce((sum, user) => sum + user.premiumShares, 0n);
    if (hubPS !== spokePS) {
      console.error(
        'hub.premiumShares !== sum(spoke.premiumShares)',
        f(hubPS),
        f(spokePS)
      );
      fail = true;
    }
    if (spokePS !== userPS) {
      console.error(
        'sum(spoke.premiumShares) !== sum(user.premiumShares)',
        f(spokePS),
        f(userPS)
      );
      fail = true;
    }

    // premiumOffsetRay: exact match (signed)
    const hubPOR = this.hub.premiumOffsetRay;
    const spokePOR = this.spokes.reduce((sum, spoke) => sum + spoke.premiumOffsetRay, 0n);
    const userPOR = this.users.reduce((sum, user) => sum + user.premiumOffsetRay, 0n);
    if (hubPOR !== spokePOR) {
      console.error(
        'hub.premiumOffsetRay !== sum(spoke.premiumOffsetRay)',
        hubPOR,
        spokePOR
      );
      fail = true;
    }
    if (spokePOR !== userPOR) {
      console.error(
        'sum(spoke.premiumOffsetRay) !== sum(user.premiumOffsetRay)',
        spokePOR,
        userPOR
      );
      fail = true;
    }

    if (hubPremiumDebt === 0n && spokePremium + userPremiumDebt !== 0n) {
      console.error(
        'spoke & user dust premiumDebt remaining when hub premiumDebt is completely repaid',
        f(spokePremium),
        f(userPremiumDebt)
      );
      fail = true;
    }

    this.handleFailure(fail, 'invariant_sumOfPremiumDebt');
  }

  invariant_sumOfAddedShares() {
    const hubAddedShares = this.hub.addedShares;
    const spokeAddedShares = this.spokes.reduce((sum, spoke) => sum + spoke.addedShares, 0n);
    const userAddedShares = this.users.reduce((sum, user) => sum + user.addedShares, 0n);
    let fail = false,
      diff = 0n;
    if ((diff = absDiff(hubAddedShares, spokeAddedShares)) > PRECISION) {
      console.error(
        'hubAddedShares !== spokeAddedShares, diff',
        f(hubAddedShares),
        f(spokeAddedShares),
        diff
      );
      fail = true;
    }
    if ((diff = absDiff(hubAddedShares, userAddedShares)) > PRECISION) {
      console.error(
        'hubAddedShares !== userAddedShares, diff',
        f(hubAddedShares),
        f(userAddedShares),
        diff
      );
      fail = true;
    }

    this.handleFailure(fail, 'invariant_sumOfAddedShares');
  }

  invariant_sumOfDeficitRay() {
    const hubDeficit = this.hub.deficitRay;
    const spokeDeficit = this.spokes.reduce((sum, spoke) => sum + spoke.deficitRay, 0n);
    let fail = false;
    if (hubDeficit !== spokeDeficit) {
      console.error('hubDeficit !== spokeDeficit', hubDeficit, spokeDeficit);
      fail = true;
    }
    this.handleFailure(fail, 'invariant_sumOfDeficitRay');
  }

  invariant_hubSpokeAccounting() {
    let fail = false;

    this.spokes.forEach((spoke) => {
      const spokeOnHub = this.hub.getSpoke(spoke);
      (
        ['drawnShares', 'premiumShares', 'premiumOffsetRay', 'addedShares', 'deficitRay'] as const
      ).forEach((key) => {
        if ((spoke as any)[key] !== (spokeOnHub as any)[key]) {
          console.error(
            `spoke(${spoke.id}).${key} ${(spoke as any)[key]} !== hub.spokes[${this.hub.idx(
              spoke
            )}].${key} ${(spokeOnHub as any)[key]}`
          );
          fail = true;
        }
      });
    });

    this.handleFailure(fail, 'invariant_hubSpokeAccountingMatch');
  }

  invariant_supplyExchangeRateIsNonDecreasing() {
    let fail = false;
    const ratio = this.hub.supplyExchangeRatio();
    const prev = this.supplyExchangeRatio;
    if (
      prev &&
      prev.totalAddedAssets > 0n &&
      (ratio.totalAddedAssets + VIRTUAL_ASSETS) * (prev.totalAddedShares + VIRTUAL_SHARES) <
        (prev.totalAddedAssets + VIRTUAL_ASSETS) * (ratio.totalAddedShares + VIRTUAL_SHARES)
    ) {
      console.error(
        'supplyExchangeRate decreased',
        Utils.ratio(ratio),
        Utils.ratio(prev),
        Utils.diff(prev, ratio)
      );
      fail = true;
    }
    this.supplyExchangeRatio = {totalAddedAssets: 0n, totalAddedShares: 0n}; // reset
    this.handleFailure(fail, 'invariant_supplyExchangeRateIsNonDecreasing');
  }

  handleFailure(fail: boolean, invariant: string) {
    if (fail) {
      throw new Error(`${invariant} failed`);
    }
  }
}

class Utils {
  static checkBounds(who: Hub | Spoke | User) {
    const vals = [who.drawnShares, who.premiumShares];
    if (who instanceof Hub) {
      vals.push(who.addedShares, who.liquidity);
    }
    if (who instanceof User) {
      vals.push(who.addedShares);
    }
    const fail = vals.reduce((flag, v) => flag || v < 0n || v > MAX_UINT, false);
    if (fail) {
      who.log(true);
      throw new Error('underflow/overflow');
    }
  }

  static ratio(r: {totalAddedAssets: bigint; totalAddedShares: bigint}) {
    const precision = 50;
    const denom = r.totalAddedShares + VIRTUAL_SHARES;
    if (denom === 0n) return '0';
    return formatUnits(
      ((r.totalAddedAssets + VIRTUAL_ASSETS) * 10n ** BigInt(precision)) / denom,
      precision
    );
  }

  static diff(
    a: {totalAddedAssets: bigint; totalAddedShares: bigint},
    b: {totalAddedAssets: bigint; totalAddedShares: bigint}
  ) {
    const precision = 50;
    const denomA = a.totalAddedShares + VIRTUAL_SHARES;
    const denomB = b.totalAddedShares + VIRTUAL_SHARES;
    if (denomA === 0n || denomB === 0n) return '0';
    return formatUnits(
      ((a.totalAddedAssets + VIRTUAL_ASSETS) * 10n ** BigInt(precision)) / denomA -
        ((b.totalAddedAssets + VIRTUAL_ASSETS) * 10n ** BigInt(precision)) / denomB,
      precision
    );
  }
}

export function skip(ms = 1n) {
  if (DEBUG) info('skipping');
  currentTime += ms;
}
