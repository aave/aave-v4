import {
  DEBUG,
  MAX_UINT,
  Rounding,
  assertNonZero,
  absDiff,
  randomRiskPremium,
  randomIndex,
  f,
  formatBps,
  mulDiv,
  percentMul,
  info,
  rayMul,
  rayDiv,
  RAY,
  PRECISION,
  maxAbsDiff,
  randomAmount,
  formatUnits,
  assertGeZero,
  min,
} from './utils';

let spokeIdCounter = 0n;
let userIdCounter = 0n;

let currentTime = 1n;

const VIRTUAL_SHARES = 10n ** 6n;

// type/token transfers to differentiate supplied/debt shares
// notify is unneeded since prototype assumes one asset on hub
export class LiquidityHub {
  public spokes: Spoke[] = [];
  public lastUpdateTimestamp = 0n;

  public baseDrawnShares = 0n; // aka totalDrawnShares
  public ghostDrawnShares = 0n;
  public offset = 0n;
  public realisedPremium = 0n;

  public baseDebtIndex = RAY;

  public availableLiquidity = 0n;

  public suppliedShares = 0n;

  // total drawn assets does not incl totalOutstandingPremium to accrue base rate separately
  toDrawnAssets(shares: bigint, rounding = Rounding.FLOOR) {
    this.accrue();
    return rayMul(shares, this.baseDebtIndex, rounding);
  }

  toDrawnShares(assets: bigint, rounding = Rounding.FLOOR) {
    this.accrue();
    return rayDiv(assets, this.baseDebtIndex, rounding);
  }

  baseDebt() {
    return this.convertToDrawnAssets(this.baseDrawnShares);
  }
  premiumDebt() {
    const accruedPremium = this.convertToPremiumDrawnAssets(this.ghostDrawnShares) - this.offset;
    assertGeZero(accruedPremium);
    return accruedPremium + this.realisedPremium;
  }

  totalSupplyAssets() {
    this.accrue();
    return this.availableLiquidity + this.baseDebt() + this.premiumDebt() + 1n;
  }
  totalSupplyShares() {
    return this.suppliedShares + VIRTUAL_SHARES;
  }

  toSupplyAssets(shares: bigint, rounding = Rounding.FLOOR) {
    return this.totalSupplyShares()
      ? mulDiv(shares, this.totalSupplyAssets(), this.totalSupplyShares(), rounding)
      : shares;
  }

  toSupplyShares(assets: bigint, rounding = Rounding.FLOOR) {
    return this.totalSupplyAssets()
      ? mulDiv(assets, this.totalSupplyShares(), this.totalSupplyAssets(), rounding)
      : assets;
  }

  accrue() {
    if (this.lastUpdateTimestamp === currentTime) return;
    this.lastUpdateTimestamp = currentTime;
    this.baseDebtIndex = rayMul(this.baseDebtIndex, randomIndex());
  }

  supply(amount: bigint, spoke: Spoke) {
    const suppliedShares = this.toSupplyShares(amount);
    assertNonZero(suppliedShares);

    this.suppliedShares += suppliedShares;
    this.availableLiquidity += amount;

    this.getSpoke(spoke).suppliedShares += suppliedShares;

    return suppliedShares;
  }

  withdraw(amount: bigint, spoke: Spoke) {
    const suppliedShares = this.toSupplyShares(amount, Rounding.CEIL);

    this.suppliedShares -= suppliedShares;
    this.availableLiquidity -= amount;

    this.getSpoke(spoke).suppliedShares -= suppliedShares;

    Utils.checkBounds(this);
    return suppliedShares;
  }

  // @dev spoke data is *expected* to be updated on the `refresh` callback
  draw(amount: bigint, spoke: Spoke) {
    const drawnShares = this.toDrawnShares(amount, Rounding.CEIL);

    this.availableLiquidity -= amount;
    this.baseDrawnShares += drawnShares;

    this.getSpoke(spoke).baseDrawnShares += drawnShares;

    return drawnShares;
  }

  // @dev global & spoke premiumDebt (ghost, offset, unrealised) is *expected* to be updated on the `refresh` callback
  restore(baseAmount: bigint, premiumAmount: bigint, spoke: Spoke) {
    const drawnShares = this.toDrawnShares(baseAmount);

    this.availableLiquidity += baseAmount + premiumAmount;
    this.baseDrawnShares -= drawnShares;

    this.getSpoke(spoke).baseDrawnShares -= drawnShares;

    return drawnShares;
  }

  refresh(
    userGhostDrawnSharesDelta: bigint,
    userOffsetDelta: bigint,
    userRealisedPremiumDelta: bigint,
    who: Spoke
  ) {
    // add invariant: offset <= premiumDebt
    // consider enforcing rp limit (per spoke) here using ghost/base (min and max cap)
    // when we agree for -ve offset, then consider another configurable check for min limit offset

    // check that total debt can only:
    // - reduce until `premiumDebt` if called after a restore (tstore premiumDebt?)
    // - remains unchanged on all other calls
    // `refresh` is game-able only for premium stuff

    let totalDebtBefore = this.getTotalDebt();
    this.ghostDrawnShares += userGhostDrawnSharesDelta;
    this.offset += userOffsetDelta;
    this.realisedPremium += userRealisedPremiumDelta;
    Utils.checkBounds(this);
    Utils.checkTotalDebt(totalDebtBefore, this);

    const spoke = this.getSpoke(who);
    totalDebtBefore = spoke.getTotalDebt();
    spoke.ghostDrawnShares += userGhostDrawnSharesDelta;
    spoke.offset += userOffsetDelta;
    spoke.realisedPremium += userRealisedPremiumDelta;
    Utils.checkBounds(spoke);
    Utils.checkTotalDebt(totalDebtBefore, spoke);
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

  log(spokes = false, users = false) {
    const ghostDebt = this.convertToDrawnAssets(this.ghostDrawnShares) - this.offset;
    console.log('--- Hub ---');
    console.log('hub.baseDrawnShares         ', f(this.baseDrawnShares));
    console.log('hub.ghostDrawnShares        ', f(this.ghostDrawnShares));
    console.log('hub.offset                  ', f(this.offset));
    console.log('hub.ghostDebt               ', f(ghostDebt));
    console.log('hub.realisedPremium         ', f(this.realisedPremium));

    console.log('hub.suppliedShares          ', f(this.suppliedShares));
    console.log('hub.totalSupplyAssets       ', f(this.totalSupplyAssets()));
    console.log('hub.availableLiquidity      ', f(this.availableLiquidity));
    console.log('hub.baseDebt                ', f(this.baseDebt()));
    console.log('hub.premiumDebt             ', f(this.premiumDebt()));
    console.log('hub.lastUpdateTimestamp     ', this.lastUpdateTimestamp);

    console.log('hub.getTotalDebt            ', f(this.getTotalDebt()));
    console.log('hub.getDebt: baseDebt       ', f(this.getDebt().baseDebt));
    console.log('hub.getDebt: premiumDebt    ', f(this.getDebt().premiumDebt));
    console.log();

    if (spokes) this.spokes.forEach((spoke) => spoke.log(false, users));
  }

  getTotalDebt() {
    return Object.values(this.getDebt()).reduce((sum, debt) => sum + debt, 0n);
  }

  getDebt() {
    this.accrue();
    const accruedPremium = this.convertToPremiumDrawnAssets(this.ghostDrawnShares) - this.offset;
    assertGeZero(accruedPremium);
    return {
      baseDebt: this.convertToDrawnAssets(this.baseDrawnShares),
      premiumDebt: accruedPremium + this.realisedPremium,
    };
  }

  convertToSuppliedAssets(shares: bigint) {
    return this.toSupplyAssets(shares);
  }
  convertToSuppliedShares(assets: bigint) {
    return this.toSupplyShares(assets);
  }

  convertToDrawnAssets(shares: bigint) {
    return this.toDrawnAssets(shares, Rounding.CEIL);
  }
  convertToDrawnShares(assets: bigint) {
    return this.toDrawnShares(assets);
  }

  convertToPremiumDrawnAssets(premiumDrawnShares: bigint) {
    return this.toDrawnAssets(premiumDrawnShares);
  }

  supplyExchangeRatio() {
    return {
      totalSuppliedAssets: this.totalSupplyAssets(),
      totalSuppliedShares: this.totalSupplyShares(),
    };
  }

  addSpoke(who: Spoke) {
    this.spokes.push(new Spoke(this, who.id)); // clone to maintain independent accounting
  }

  whoami() {
    return 'LiquidityHub';
  }
}

export class Spoke {
  public users: User[] = [];

  public baseDrawnShares = 0n;
  public ghostDrawnShares = 0n;
  public offset = 0n;
  public realisedPremium = 0n;

  public suppliedShares = 0n;

  constructor(public hub: LiquidityHub, public readonly id = ++spokeIdCounter) {}

  supply(amount: bigint, who: User) {
    const user = this.getUser(who);

    this.hub.accrue();
    const suppliedShares = this.hub.supply(amount, this);

    this.suppliedShares += suppliedShares;
    user.suppliedShares += suppliedShares;

    this.updateUserRiskPremium(user);

    return suppliedShares;
  }

  withdraw(amount: bigint, who: User) {
    const user = this.getUser(who);

    this.hub.accrue();
    amount = min(amount, user.getSuppliedBalance());
    const suppliedShares = this.hub.withdraw(amount, this);

    this.suppliedShares -= suppliedShares;
    user.suppliedShares -= suppliedShares;

    this.updateUserRiskPremium(user);

    return suppliedShares;
  }

  borrow(amount: bigint, who: User) {
    const user = this.getUser(who);

    this.hub.accrue();

    let userGhostDrawnShares = user.ghostDrawnShares;
    let userOffset = user.offset;
    const accruedPremium = this.hub.convertToPremiumDrawnAssets(userGhostDrawnShares) - userOffset;
    assertGeZero(accruedPremium);

    user.ghostDrawnShares = 0n;
    user.offset = 0n;
    user.realisedPremium += accruedPremium;

    this.refresh(-userGhostDrawnShares, -userOffset, accruedPremium, user);
    const drawnShares = this.hub.draw(amount, this); // asset to share should round up

    this.baseDrawnShares += drawnShares;
    user.baseDrawnShares += drawnShares;

    user.riskPremium = randomRiskPremium();
    userGhostDrawnShares = user.ghostDrawnShares = percentMul(
      user.baseDrawnShares,
      user.riskPremium
    );
    userOffset = user.offset = this.hub.convertToPremiumDrawnAssets(user.ghostDrawnShares);

    this.refresh(userGhostDrawnShares, userOffset, 0n, user);

    return drawnShares;
  }

  repay(amount: bigint, who: User) {
    const user = this.getUser(who);

    this.hub.accrue();
    const {baseDebt, premiumDebt} = this.getUserDebt(user);
    const {baseDebtRestored, premiumDebtRestored} = this.deductFromPremium(
      baseDebt,
      premiumDebt,
      amount,
      user
    );

    let userGhostDrawnShares = user.ghostDrawnShares;
    let userOffset = user.offset;
    const userRealisedPremium = user.realisedPremium;
    user.ghostDrawnShares = 0n;
    user.offset = 0n;
    user.realisedPremium = premiumDebt - premiumDebtRestored;
    this.refresh(
      -userGhostDrawnShares,
      -userOffset,
      user.realisedPremium - userRealisedPremium,
      user
    ); // settle premium debt
    const drawnShares = this.hub.restore(baseDebtRestored, premiumDebtRestored, this); // settle base debt

    this.baseDrawnShares -= drawnShares;
    user.baseDrawnShares -= drawnShares;

    user.riskPremium = randomRiskPremium();
    userGhostDrawnShares = user.ghostDrawnShares = percentMul(
      user.baseDrawnShares,
      user.riskPremium
    );
    userOffset = user.offset = this.hub.convertToPremiumDrawnAssets(user.ghostDrawnShares);

    this.refresh(userGhostDrawnShares, userOffset, 0n, user);

    return [drawnShares, premiumDebtRestored];
  }

  deductFromPremium(baseDebt: bigint, premiumDebt: bigint, amount: bigint, user: User) {
    if (amount === MAX_UINT) {
      return {baseDebtRestored: baseDebt, premiumDebtRestored: premiumDebt};
    }

    let baseDebtRestored = 0n,
      premiumDebtRestored = 0n;

    if (amount < premiumDebt) {
      baseDebtRestored = 0n;
      premiumDebtRestored = amount;
    } else {
      baseDebtRestored = amount - premiumDebt;
      premiumDebtRestored = premiumDebt;
    }

    // sanity
    if (baseDebtRestored > baseDebt) {
      user.log(true, true);
      info(
        'baseDebtRestored, baseDebt, diff',
        f(baseDebtRestored),
        f(baseDebt),
        absDiff(baseDebtRestored, baseDebt)
      );
      throw new Error('baseDebtRestored exceeds baseDebt');
    }

    if (premiumDebtRestored > premiumDebt) {
      user.log(true, true);
      info(
        'premiumDebtRestored, premiumDebt, diff',
        f(premiumDebtRestored),
        f(premiumDebt),
        absDiff(premiumDebtRestored, premiumDebt)
      );
      throw new Error('premiumDebtRestored exceeds premiumDebt');
    }

    return {baseDebtRestored, premiumDebtRestored};
  }

  updateUserRiskPremium(who: User) {
    const user = this.getUser(who);
    user.riskPremium = randomRiskPremium();

    const oldUserGhostDrawnShares = user.ghostDrawnShares;
    const oldUserOffset = user.offset;

    user.ghostDrawnShares = percentMul(user.baseDrawnShares, user.riskPremium);
    user.offset = this.hub.convertToPremiumDrawnAssets(user.ghostDrawnShares);

    const accruedPremium =
      this.hub.convertToPremiumDrawnAssets(oldUserGhostDrawnShares) - oldUserOffset;
    user.realisedPremium += accruedPremium;

    this.refresh(
      user.ghostDrawnShares - oldUserGhostDrawnShares,
      user.offset - oldUserOffset,
      accruedPremium,
      user
    );
  }

  refresh(
    userGhostDrawnSharesDelta: bigint,
    userOffsetDelta: bigint,
    userRealisedPremiumDelta: bigint,
    user: User
  ) {
    Utils.checkBounds(user);

    const totalDebtBefore = this.getTotalDebt();
    this.ghostDrawnShares += userGhostDrawnSharesDelta;
    this.offset += userOffsetDelta;
    this.realisedPremium += userRealisedPremiumDelta;
    Utils.checkBounds(this);
    Utils.checkTotalDebt(totalDebtBefore, this);

    this.hub.refresh(userGhostDrawnSharesDelta, userOffsetDelta, userRealisedPremiumDelta, this);
  }

  getTotalDebt() {
    return Object.values(this.getDebt()).reduce((sum, debt) => sum + debt, 0n);
  }

  getDebt() {
    this.hub.accrue();
    const accruedPremium =
      this.hub.convertToPremiumDrawnAssets(this.ghostDrawnShares) - this.offset;
    assertGeZero(accruedPremium);
    return {
      baseDebt: this.hub.convertToDrawnAssets(this.baseDrawnShares),
      premiumDebt: accruedPremium + this.realisedPremium,
    };
  }

  getUserDebt(who: User) {
    this.hub.accrue();
    const user = this.getUser(who);
    const accruedPremium =
      this.hub.convertToPremiumDrawnAssets(user.ghostDrawnShares) - user.offset;
    assertGeZero(accruedPremium);
    return {
      baseDebt: this.hub.convertToDrawnAssets(user.baseDrawnShares),
      premiumDebt: accruedPremium + user.realisedPremium,
    };
  }

  getUserTotalDebt(who: User) {
    return Object.values(this.getUserDebt(who)).reduce((sum, debt) => sum + debt, 0n);
  }

  addUser(user: User) {
    // store user reference since we don't back update since it's an eoa
    this.users.push(user);
    user.assignSpoke(this);
  }

  getUser(user: User | number) {
    if (typeof user === 'number') return this.users[user];
    return this.users[this.idx(user)];
  }

  idx(user: User) {
    const idx = this.users.findIndex((s) => s.id === user.id);
    if (idx === -1) {
      this.addUser(user);
      user.assignSpoke(this);
      return this.users.length - 1;
    }
    return idx;
  }

  log(hub = false, users = false) {
    const ghostDebt = this.hub.convertToPremiumDrawnAssets(this.ghostDrawnShares) - this.offset;
    console.log(`--- Spoke ${this.id} ---`);
    console.log('spoke.baseDrawnShares       ', f(this.baseDrawnShares));
    console.log('spoke.ghostDrawnShares      ', f(this.ghostDrawnShares));
    console.log('spoke.offset                ', f(this.offset));
    console.log('spoke.ghostDebt             ', f(ghostDebt));
    console.log('spoke.realisedPremium       ', f(this.realisedPremium));
    console.log('spoke.suppliedShares        ', f(this.suppliedShares));
    console.log('spoke.getTotalDebt          ', f(this.getTotalDebt()));
    console.log('spoke.getDebt: baseDebt     ', f(this.getDebt().baseDebt));
    console.log('spoke.getDebt: premiumDebt  ', f(this.getDebt().premiumDebt));
    console.log();
    if (hub) this.hub.log();
    if (users) this.users.forEach((user) => user.log());
  }

  whoami() {
    return `Spoke ${this.id}`;
  }
}

export class User {
  public spoke: Spoke;
  public hub: LiquidityHub;

  public baseDrawnShares = 0n;
  public ghostDrawnShares = 0n;
  public offset = 0n;
  public realisedPremium = 0n;

  public suppliedShares = 0n;

  constructor(
    public readonly id = ++userIdCounter,
    public riskPremium = randomRiskPremium(), // don't need to store, can be derived from `ghost/base`
    spoke: Spoke | null = null
  ) {
    if (spoke) this.assignSpoke(spoke);
  }

  supply(amount: bigint) {
    this.beforeHook('supply', amount);
    const suppliedShares = this.spoke.supply(amount, this);
    this.afterHook();
    return suppliedShares;
  }

  withdraw(amount: bigint) {
    this.beforeHook('withdraw', amount);
    const withdrawnShares = this.spoke.withdraw(amount, this);
    this.afterHook();
    return withdrawnShares;
  }

  borrow(amount: bigint) {
    this.beforeHook('borrow', amount);
    const drawnShares = this.spoke.borrow(amount, this);
    this.afterHook();
    return drawnShares;
  }

  repay(amount: bigint) {
    this.beforeHook('repay', amount);
    const [baseDebtSharesRestored, premiumAmountRestored] = this.spoke.repay(amount, this);
    this.afterHook();
    return [baseDebtSharesRestored, premiumAmountRestored];
  }

  updateRiskPremium() {
    this.beforeHook('updateRiskPremium');
    this.spoke.updateUserRiskPremium(this);
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
    return this.hub.convertToSuppliedAssets(this.suppliedShares);
  }

  log(spoke = false, hub = false) {
    const ghostDebt = this.hub.convertToDrawnAssets(this.ghostDrawnShares) - this.offset;
    console.log(`--- User ${this.id} ---`);
    console.log('user.baseDrawnShares        ', f(this.baseDrawnShares));
    console.log('user.ghostDrawnShares       ', f(this.ghostDrawnShares));
    console.log('user.offset                 ', f(this.offset));
    console.log('user.ghostDebt              ', f(ghostDebt));
    console.log('user.realisedPremium        ', f(this.realisedPremium));
    console.log('user.suppliedShares         ', f(this.suppliedShares));
    console.log('user.riskPremium            ', formatBps(this.riskPremium));
    console.log('user.getTotalDebt           ', f(this.spoke.getUserTotalDebt(this)));
    console.log('user.getDebt: baseDebt      ', f(this.spoke.getUserDebt(this).baseDebt));
    console.log('user.getDebt: premiumDebt   ', f(this.spoke.getUserDebt(this).premiumDebt));
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
  public hub: LiquidityHub;
  public spokes: Spoke[];
  public users: User[];

  public supplyExchangeRatio: ReturnType<typeof LiquidityHub.prototype.supplyExchangeRatio>;

  constructor(numSpokes = 1, numUsers = 3) {
    this.hub = new LiquidityHub();
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
          formatUnits(this.hub.convertToDrawnAssets(10n ** 50n), 50) // bigint won't overflow
        );

        this.supplyExchangeRatio = this.hub.supplyExchangeRatio();
      };
      user.afterHook = () => {
        // should always increase on an accrue
        this.invariant_supplyExchangeRateIsNonDecreasing();
        this.runInvariants();
      };
    });
  }

  nonZeroSuppliedShares(amount: bigint) {
    while (this.hub.convertToSuppliedShares(amount) === 0n) amount = randomAmount();
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
    this.invariant_sumOfBaseDebt();
    this.invariant_sumOfPremiumDebt();
    this.invariant_sumOfSuppliedShares();
    this.invariant_hubSpokeAccounting();
    // todo invariant: both exchange ratio are always increasing with the offset fix
  }

  invariant_valuesWithinBounds() {
    let fail = false;
    const all = [this.hub, ...this.spokes, ...this.users];
    ['baseDrawnShares', 'ghostDrawnShares', 'offset', 'realisedPremium', 'suppliedShares'].forEach(
      (key) => {
        all.forEach((who) => {
          if (who[key] < 0n || who[key] > MAX_UINT) {
            who.log(who instanceof User, who instanceof User);
            console.error(`${who.whoami()}.${key} < 0 || > MAX_UINT`, f(who[key]));
            fail = true;
          }
        });
      }
    );
    // ghost drawn assets >= offset, always
    all.forEach((who) => {
      const ghostDrawnAssets = this.hub.convertToDrawnAssets(who.ghostDrawnShares);
      if (ghostDrawnAssets < who.offset) {
        who.log();
        console.error(
          `assets(${who.whoami()}.ghostDrawnShares) < offset, ghostDrawnShares, diff`,
          f(ghostDrawnAssets),
          f(who.offset),
          f(who.ghostDrawnShares),
          who.offset - ghostDrawnAssets
        );
        fail = true;
      }
    });

    this.handleFailure(fail, 'invariant_valuesWithinBounds');
  }

  invariant_sumOfBaseDebt() {
    let fail = false,
      diff = 0n;
    const hubBaseDebt = this.hub.getDebt().baseDebt;
    const spokeBaseDebt = this.spokes.reduce((sum, spoke) => sum + spoke.getDebt().baseDebt, 0n);
    const userBaseDebt = this.users.reduce((sum, user) => sum + user.getDebt().baseDebt, 0n);
    if ((diff = absDiff(hubBaseDebt, spokeBaseDebt)) > PRECISION) {
      console.error('hubBaseDebt !== spokeBaseDebt, diff', f(hubBaseDebt), f(spokeBaseDebt), diff);
      fail = true;
    }
    if ((diff = absDiff(spokeBaseDebt, userBaseDebt)) > PRECISION) {
      console.error(
        'spokeBaseDebt !== userBaseDebt, diff',
        f(spokeBaseDebt),
        f(userBaseDebt),
        diff
      );
      fail = true;
    }
    if ((diff = maxAbsDiff(hubBaseDebt, spokeBaseDebt, userBaseDebt)) > PRECISION) {
      console.error(
        'maxAbsDiff(hubBaseDebt, spokeBaseDebt, userBaseDebt) > PRECISION, diff',
        f(hubBaseDebt),
        f(spokeBaseDebt),
        f(userBaseDebt),
        diff
      );
      fail = true;
    }

    if (hubBaseDebt === 0n && spokeBaseDebt + userBaseDebt !== 0n) {
      console.error(
        'spoke & user dust baseDebt remaining when hub baseDebt is completely repaid',
        'spokeBaseDebt %d, userBaseDebt %d',
        f(spokeBaseDebt),
        f(userBaseDebt)
      );
      fail = true;
    }

    // this.handleFailure(fail, arguments.callee.name);
    this.handleFailure(fail, 'invariant_sumOfBaseDebt');
  }

  invariant_sumOfPremiumDebt() {
    let fail = false,
      diff = 0n;
    const hubPremiumDebt = this.hub.getDebt().premiumDebt;
    const spokePremiumDebt = this.spokes.reduce(
      (sum, spoke) => sum + spoke.getDebt().premiumDebt,
      0n
    );
    const userPremiumDebt = this.users.reduce((sum, user) => sum + user.getDebt().premiumDebt, 0n);
    if ((diff = absDiff(hubPremiumDebt, spokePremiumDebt)) > PRECISION) {
      console.error(
        'hubPremiumDebt !== spokePremiumDebt, diff',
        f(hubPremiumDebt),
        f(spokePremiumDebt),
        diff
      );
      fail = true;
    }
    if ((diff = absDiff(spokePremiumDebt, userPremiumDebt)) > PRECISION) {
      console.error(
        'spokePremiumDebt !== userPremiumDebt, diff',
        f(spokePremiumDebt),
        f(userPremiumDebt),
        diff
      );
      fail = true;
    }

    // validate internal premium vars
    ['ghostDrawnShares', 'offset', 'realisedPremium'].forEach((key) => {
      const hubKey = this.hub[key];
      const spokeKey = this.spokes.reduce((sum, spoke) => sum + spoke[key], 0n);
      const userKey = this.users.reduce((sum, user) => sum + user[key], 0n);
      if ((diff = absDiff(hubKey, spokeKey)) > PRECISION) {
        console.error(`this.hub.${key} !== spoke.${key}, diff`, f(hubKey), f(spokeKey), diff);
        fail = true;
      }
      if ((diff = absDiff(spokeKey, userKey)) > PRECISION) {
        console.error(`spoke.${key} !== user.${key}, diff`, f(spokeKey), f(userKey), diff);
        fail = true;
      }
    });

    if (hubPremiumDebt === 0n && spokePremiumDebt + userPremiumDebt !== 0n) {
      console.error(
        'spoke & user dust premiumDebt remaining when hub premiumDebt is completely repaid',
        'spokePremiumDebt %d, userPremiumDebt %d',
        f(spokePremiumDebt),
        f(userPremiumDebt)
      );
      fail = true;
    }

    this.handleFailure(fail, 'invariant_sumOfPremiumDebt');
  }

  invariant_sumOfSuppliedShares() {
    const hubSuppliedShares = this.hub.suppliedShares;
    const spokeSuppliedShares = this.spokes.reduce((sum, spoke) => sum + spoke.suppliedShares, 0n);
    const userSuppliedShares = this.users.reduce((sum, user) => sum + user.suppliedShares, 0n);
    let fail = false,
      diff = 0n;
    if ((diff = absDiff(hubSuppliedShares, spokeSuppliedShares)) > PRECISION) {
      console.error(
        'hubSuppliedShares !== spokeSuppliedShares, diff',
        f(hubSuppliedShares),
        f(spokeSuppliedShares),
        diff
      );
      fail = true;
    }
    if ((diff = absDiff(hubSuppliedShares, userSuppliedShares)) > PRECISION) {
      console.error(
        'hubSuppliedShares !== userSuppliedShares, diff',
        f(hubSuppliedShares),
        f(userSuppliedShares),
        diff
      );
      fail = true;
    }

    this.handleFailure(fail, 'invariant_sumOfSuppliedShares');
  }

  invariant_hubSpokeAccounting() {
    let fail = false;

    this.spokes.forEach((spoke) => {
      const spokeOnHub = this.hub.getSpoke(spoke);
      [
        'baseDrawnShares',
        'ghostDrawnShares',
        'offset',
        'realisedPremium',
        'suppliedShares',
      ].forEach((key) => {
        if (spoke[key] !== spokeOnHub[key]) {
          console.error(
            `spoke(${spoke.id}).${key} ${f(spoke[key])} !== this.hub.spokes[${this.hub.idx(
              spoke
            )}].${key} ${f(spokeOnHub[key])}`
          );
          fail = true;
        }
      });
    });

    this.handleFailure(fail, 'invariant_hubSpokeAccountingMatch');
  }

  invariant_supplyExchangeRateIsNonDecreasing() {
    let fail = false;
    const supplyExchangeRatio = this.hub.supplyExchangeRatio();
    if (
      supplyExchangeRatio.totalSuppliedAssets * this.supplyExchangeRatio.totalSuppliedShares <
      this.supplyExchangeRatio.totalSuppliedAssets * supplyExchangeRatio.totalSuppliedShares
    ) {
      console.error(
        'supplyExchangeRatio < this.supplyExchangeRatio, diff',
        Utils.ratio(supplyExchangeRatio),
        Utils.ratio(this.supplyExchangeRatio),
        Utils.diff(this.supplyExchangeRatio, supplyExchangeRatio)
      );
      fail = true;
    }
    this.supplyExchangeRatio = {totalSuppliedAssets: 0n, totalSuppliedShares: 0n}; // reset
    this.handleFailure(fail, 'invariant_supplyExchangeRateIsNonDecreasing');
  }

  handleFailure(fail: boolean, invariant: string) {
    if (fail) {
      // hub.log(true);
      // spokes.forEach((spoke) => spoke.log());
      // users.forEach((user) => user.log());
      throw new Error(`${invariant} failed`);
    }
  }
}

class Utils {
  static checkTotalDebt(totalDebtBefore: bigint, who: LiquidityHub | Spoke | User) {
    const totalDebtAfter = who.getTotalDebt();
    const diff = totalDebtAfter - totalDebtBefore;
    if (totalDebtAfter > totalDebtBefore && diff > 1n) {
      who.log(true);
      console.error(
        'totalDebtAfter > totalDebtBefore, diff',
        f(totalDebtAfter),
        f(totalDebtBefore),
        diff
      );
      throw new Error('totalDebt increased');
    }
  }

  static checkBounds(who: LiquidityHub | Spoke | User) {
    const fail = [
      who.baseDrawnShares,
      who.ghostDrawnShares,
      who.offset,
      who.realisedPremium,
      ...(who instanceof LiquidityHub
        ? [who.suppliedShares, who.totalSupplyAssets(), who.premiumDebt(), who.availableLiquidity]
        : []),
    ].reduce((flag, v) => flag || v < 0n || v > MAX_UINT, false);
    if (fail) {
      who.log(true);
      throw new Error('underflow/overflow');
    }
  }

  static ratio(supplyExchangeRatio: ReturnType<typeof LiquidityHub.prototype.supplyExchangeRatio>) {
    const precision = 50;
    return formatUnits(
      (supplyExchangeRatio.totalSuppliedAssets * 10n ** BigInt(precision)) /
        supplyExchangeRatio.totalSuppliedShares,
      precision
    );
  }

  static diff(
    a: ReturnType<typeof LiquidityHub.prototype.supplyExchangeRatio>,
    b: ReturnType<typeof LiquidityHub.prototype.supplyExchangeRatio>
  ) {
    const precision = 50;
    return formatUnits(
      (a.totalSuppliedAssets * 10n ** BigInt(precision)) / a.totalSuppliedShares -
        (b.totalSuppliedAssets * 10n ** BigInt(precision)) / b.totalSuppliedShares,
      precision
    );
  }
}

export function skip(ms = 1n) {
  if (DEBUG) info('skipping');
  currentTime += ms;
}
