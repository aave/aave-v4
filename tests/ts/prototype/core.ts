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
  inverse,
} from './utils';

let spokeIdCounter = 0n;
let userIdCounter = 0n;

let currentTime = 1n;

const OFFSET_UNITS = 10n ** 6n;

// type/token transfers to differentiate supplied/debt shares
// notify is unneeded since prototype assumes one asset on hub
export class LiquidityHub {
  public spokes: Spoke[] = [];
  public lastUpdateTimestamp = 0n;

  public baseDrawnShares = 0n; // aka totalDrawnShares
  public ghostDrawnShares = 0n;
  public offset = 0n;
  public unrealisedPremium = 0n;

  public drawnAssets = 0n;

  public availableLiquidity = 0n;

  public suppliedShares = 0n;

  totalDrawnAssets() {
    return this.drawnAssets + OFFSET_UNITS;
  }
  totalDrawnShares() {
    return this.baseDrawnShares + OFFSET_UNITS;
  }

  // total drawn assets does not incl totalOutstandingPremium to accrue base rate separately
  toDrawnAssets(shares: bigint, rounding = Rounding.FLOOR) {
    this.accrue();
    return mulDiv(shares, this.totalDrawnAssets(), this.totalDrawnShares(), rounding);
  }

  toDrawnShares(assets: bigint, rounding = Rounding.FLOOR) {
    this.accrue();
    return mulDiv(assets, this.totalDrawnShares(), this.totalDrawnAssets(), rounding);
  }

  totalOutstandingPremium(rounding = Rounding.FLOOR) {
    return (
      this.toDrawnAssets(this.ghostDrawnShares, rounding) - this.offset + this.unrealisedPremium
    );
  }

  totalSupplyAssets(rounding = Rounding.FLOOR) {
    this.accrue();
    return (
      this.availableLiquidity +
      this.drawnAssets +
      this.totalOutstandingPremium(rounding) +
      OFFSET_UNITS
    );
  }
  totalSupplyShares() {
    return this.suppliedShares + OFFSET_UNITS;
  }

  toSupplyAssets(shares: bigint, rounding = Rounding.FLOOR) {
    return mulDiv(shares, this.totalSupplyAssets(rounding), this.totalSupplyShares(), rounding);
  }

  toSupplyShares(assets: bigint, rounding = Rounding.FLOOR) {
    return mulDiv(assets, this.totalSupplyShares(), this.totalSupplyAssets(rounding), rounding);
  }

  accrue() {
    if (this.lastUpdateTimestamp === currentTime) return;
    this.lastUpdateTimestamp = currentTime;
    this.drawnAssets = rayMul(this.drawnAssets, randomIndex());
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

    return suppliedShares;
  }

  // @dev spoke data is *expected* to be updated on the `refresh` callback
  draw(amount: bigint, spoke: Spoke) {
    const drawnShares = this.toDrawnShares(amount, Rounding.CEIL);

    this.availableLiquidity -= amount;

    this.baseDrawnShares += drawnShares;
    this.drawnAssets += amount;

    this.getSpoke(spoke).baseDrawnShares += drawnShares;

    return drawnShares;
  }

  // @dev global & spoke premiumDebt (ghost, offset, unrealised) is *expected* to be updated on the `refresh` callback
  restore(baseAmount: bigint, premiumAmount: bigint, spoke: Spoke) {
    const baseDrawnSharesRestored = this.toDrawnShares(baseAmount, Rounding.CEIL);

    this.availableLiquidity += baseAmount + premiumAmount;

    this.drawnAssets -= baseAmount;
    this.baseDrawnShares -= baseDrawnSharesRestored;

    this.getSpoke(spoke).baseDrawnShares -= baseDrawnSharesRestored;

    return baseDrawnSharesRestored;
  }

  refresh(
    userGhostDrawnSharesDelta: bigint,
    userOffsetDelta: bigint,
    userUnrealisedPremiumDelta: bigint,
    who: Spoke
  ) {
    // add invariant: offset <= premiumDebt
    // consider enforcing rp limit (per spoke) here using ghost/base (min and max cap)
    // when we agree for -ve offset, then consider another configurable check for min limit offset

    // check that total debt can only:
    // - reduce until `premiumDebt` if called after a restore (tstore premiumDebt?)
    // - remains unchanged on all other calls
    // `refresh` is game-able only for premium stuff

    let totalDebtBefore = this.getTotalDebt(Rounding.CEIL);
    this.ghostDrawnShares += userGhostDrawnSharesDelta;
    this.offset += userOffsetDelta;
    this.unrealisedPremium += userUnrealisedPremiumDelta;
    Utils.checkBounds(this);
    Utils.checkTotalDebt(totalDebtBefore, this);

    const spoke = this.getSpoke(who);
    totalDebtBefore = spoke.getTotalDebt(Rounding.CEIL);
    spoke.ghostDrawnShares += userGhostDrawnSharesDelta;
    spoke.offset += userOffsetDelta;
    spoke.unrealisedPremium += userUnrealisedPremiumDelta;
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
    const ghostDebt = this.toDrawnAssets(this.ghostDrawnShares, Rounding.CEIL) - this.offset;
    console.log('--- Hub ---');
    console.log('hub.drawnAssets             ', f(this.drawnAssets));
    console.log('hub.baseDrawnShares         ', f(this.baseDrawnShares));
    console.log('hub.ghostDrawnShares        ', f(this.ghostDrawnShares));
    console.log('hub.offset                  ', f(this.offset));
    console.log('hub.ghostDebt               ', f(ghostDebt));
    console.log('hub.unrealisedPremium       ', f(this.unrealisedPremium));

    console.log('hub.suppliedShares          ', f(this.suppliedShares));
    console.log('hub.totalSupplyAssets       ', f(this.totalSupplyAssets()));
    console.log('hub.availableLiquidity      ', f(this.availableLiquidity));
    console.log('hub.totalOutstandingPremium ', f(this.totalOutstandingPremium()));
    console.log('hub.lastUpdateTimestamp     ', this.lastUpdateTimestamp);

    console.log('hub.getTotalDebt            ', f(this.getTotalDebt()));
    console.log('hub.getDebt: baseDebt       ', f(this.getDebt().baseDebt));
    console.log('hub.getDebt: premiumDebt    ', f(this.getDebt().premiumDebt));
    console.log();

    if (spokes) this.spokes.forEach((spoke) => spoke.log(false, users));
  }

  getTotalDebt(rounding = Rounding.FLOOR) {
    return Object.values(this.getDebt(rounding)).reduce((sum, debt) => sum + debt, 0n);
  }

  getDebt(rounding = Rounding.FLOOR) {
    this.accrue();
    return {
      baseDebt: this.toDrawnAssets(this.baseDrawnShares, rounding),
      premiumDebt:
        this.toDrawnAssets(this.ghostDrawnShares, rounding) - this.offset + this.unrealisedPremium,
    };
  }

  addSpoke(who: Spoke) {
    this.spokes.push(new Spoke(this, who.id)); // clone to maintain independent accounting
  }
}

export class Spoke {
  public users: User[] = [];

  public baseDrawnShares = 0n;
  public ghostDrawnShares = 0n;
  public offset = 0n;
  public unrealisedPremium = 0n;

  public suppliedShares = 0n;

  constructor(public hub: LiquidityHub, public id = ++spokeIdCounter) {}

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
    const suppliedShares = this.hub.withdraw(amount, this);

    this.suppliedShares -= suppliedShares;
    user.suppliedShares -= suppliedShares;

    this.updateUserRiskPremium(user);

    return suppliedShares;
  }

  borrow(amount: bigint, who: User) {
    const user = this.getUser(who);

    this.hub.accrue();

    const oldUserGhostDrawnShares = user.ghostDrawnShares;
    const oldUserOffset = user.offset;
    const accruedPremiumDebt =
      this.hub.toDrawnAssets(oldUserGhostDrawnShares, Rounding.CEIL) - oldUserOffset;

    const drawnShares = this.hub.draw(amount, this); // asset to share should round up

    this.baseDrawnShares += drawnShares;
    user.baseDrawnShares += drawnShares;
    user.riskPremium = randomRiskPremium();

    user.ghostDrawnShares = percentMul(user.baseDrawnShares, user.riskPremium);
    user.offset = this.hub.toDrawnAssets(user.ghostDrawnShares, Rounding.CEIL);
    user.unrealisedPremium += accruedPremiumDebt;

    this.refresh(
      user.ghostDrawnShares - oldUserGhostDrawnShares,
      user.offset - oldUserOffset,
      accruedPremiumDebt,
      user
    );

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
    const userUnrealisedPremium = user.unrealisedPremium;
    user.ghostDrawnShares = 0n;
    user.offset = 0n;
    user.unrealisedPremium = premiumDebt - premiumDebtRestored;
    this.refresh(
      user.ghostDrawnShares - userGhostDrawnShares,
      user.offset - userOffset,
      user.unrealisedPremium - userUnrealisedPremium,
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
    userOffset = user.offset = this.hub.toDrawnAssets(user.ghostDrawnShares);

    this.refresh(userGhostDrawnShares, userOffset, 0n, user);

    return drawnShares;
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
    user.offset = this.hub.toDrawnAssets(user.ghostDrawnShares, Rounding.CEIL);

    const newUnrealisedPremium =
      this.hub.toDrawnAssets(oldUserGhostDrawnShares, Rounding.CEIL) - oldUserOffset;
    user.unrealisedPremium += newUnrealisedPremium;

    this.refresh(
      user.ghostDrawnShares - oldUserGhostDrawnShares,
      user.offset - oldUserOffset,
      newUnrealisedPremium,
      user
    );
  }

  refresh(
    userGhostDrawnSharesDelta: bigint,
    userOffsetDelta: bigint,
    userUnrealisedPremiumDelta: bigint,
    user: User
  ) {
    Utils.checkBounds(user);

    const totalDebtBefore = this.getTotalDebt(Rounding.CEIL);
    this.ghostDrawnShares += userGhostDrawnSharesDelta;
    this.offset += userOffsetDelta;
    this.unrealisedPremium += userUnrealisedPremiumDelta;
    Utils.checkBounds(this);
    Utils.checkTotalDebt(totalDebtBefore, this);

    this.hub.refresh(userGhostDrawnSharesDelta, userOffsetDelta, userUnrealisedPremiumDelta, this);
  }

  getTotalDebt(rounding = Rounding.FLOOR) {
    return Object.values(this.getDebt(rounding)).reduce((sum, debt) => sum + debt, 0n);
  }

  getDebt(rounding = Rounding.FLOOR) {
    this.hub.accrue();
    return {
      baseDebt: this.hub.toDrawnAssets(this.baseDrawnShares, rounding),
      premiumDebt:
        this.hub.toDrawnAssets(this.ghostDrawnShares, rounding) -
        this.offset +
        this.unrealisedPremium,
    };
  }

  getUserDebt(who: User, rounding = Rounding.FLOOR) {
    this.hub.accrue();
    const user = this.getUser(who);
    return {
      baseDebt: this.hub.toDrawnAssets(user.baseDrawnShares, rounding),
      premiumDebt:
        this.hub.toDrawnAssets(user.ghostDrawnShares, rounding) -
        user.offset +
        user.unrealisedPremium,
    };
  }

  getUserTotalDebt(who: User, rounding = Rounding.FLOOR) {
    return Object.values(this.getUserDebt(who, rounding)).reduce((sum, debt) => sum + debt, 0n);
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
    const ghostDebt = this.hub.toDrawnAssets(this.ghostDrawnShares, Rounding.CEIL) - this.offset;
    console.log(`--- Spoke ${this.id} ---`);
    console.log('spoke.baseDrawnShares       ', f(this.baseDrawnShares));
    console.log('spoke.ghostDrawnShares      ', f(this.ghostDrawnShares));
    console.log('spoke.offset                ', f(this.offset));
    console.log('spoke.ghostDebt             ', f(ghostDebt));
    console.log('spoke.unrealisedPremium     ', f(this.unrealisedPremium));
    console.log('spoke.suppliedShares        ', f(this.suppliedShares));
    console.log('spoke.getTotalDebt          ', f(this.getTotalDebt()));
    console.log('spoke.getDebt: baseDebt     ', f(this.getDebt().baseDebt));
    console.log('spoke.getDebt: premiumDebt  ', f(this.getDebt().premiumDebt));
    console.log();
    if (hub) this.hub.log();
    if (users) this.users.forEach((user) => user.log());
  }
}

export class User {
  public spoke: Spoke;
  public hub: LiquidityHub;

  public baseDrawnShares = 0n;
  public ghostDrawnShares = 0n;
  public offset = 0n;
  public unrealisedPremium = 0n;

  public suppliedShares = 0n;

  constructor(
    public id = ++userIdCounter,
    public riskPremium = randomRiskPremium(), // don't need to store, can be derived from `ghost/base`
    spoke: Spoke | null = null
  ) {
    if (spoke) this.assignSpoke(spoke);
  }

  supply(amount: bigint) {
    info('action supply', 'id', this.id, 'amount', f(amount));
    return this.spoke.supply(amount, this);
  }

  withdraw(amount: bigint) {
    info('action withdraw', 'id', this.id, 'amount', f(amount));
    return this.spoke.withdraw(amount, this);
  }

  borrow(amount: bigint) {
    info('action borrow', 'id', this.id, 'amount', f(amount));
    return this.spoke.borrow(amount, this);
  }

  repay(amount: bigint) {
    info('action repay', 'id', this.id, 'amount', f(amount));
    return this.spoke.repay(amount, this);
  }

  updateRiskPremium() {
    info('action updateRiskPremium', 'id', this.id);
    this.spoke.updateUserRiskPremium(this);
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
    return this.hub.toSupplyAssets(this.suppliedShares);
  }

  log(spoke = false, hub = false) {
    const ghostDebt = this.hub.toDrawnAssets(this.ghostDrawnShares, Rounding.CEIL) - this.offset;
    console.log(`--- User ${this.id} ---`);
    console.log('user.baseDrawnShares        ', f(this.baseDrawnShares));
    console.log('user.ghostDrawnShares       ', f(this.ghostDrawnShares));
    console.log('user.offset                 ', f(this.offset));
    console.log('user.ghostDebt              ', f(ghostDebt));
    console.log('user.unrealisedPremium      ', f(this.unrealisedPremium));
    console.log('user.suppliedShares         ', f(this.suppliedShares));
    console.log('user.riskPremium            ', formatBps(this.riskPremium));
    console.log('user.getTotalDebt           ', f(this.spoke.getUserTotalDebt(this)));
    console.log('user.getDebt: baseDebt      ', f(this.spoke.getUserDebt(this).baseDebt));
    console.log('user.getDebt: premiumDebt   ', f(this.spoke.getUserDebt(this).premiumDebt));
    console.log();
    if (spoke) this.spoke.log();
    if (hub) this.hub.log();
  }
}

class Utils {
  static checkTotalDebt(totalDebtBefore: bigint, who: LiquidityHub | Spoke | User) {
    const totalDebtAfter = who.getTotalDebt(Rounding.CEIL);
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
      who.unrealisedPremium,
      ...(who instanceof LiquidityHub
        ? [
            who.suppliedShares,
            who.totalSupplyAssets(),
            who.totalOutstandingPremium(),
            who.availableLiquidity,
            who.drawnAssets,
          ]
        : []),
    ].reduce((flag, v) => flag || v < 0n || v > MAX_UINT, false);
    if (fail) {
      who.log(true);
      throw new Error('underflow/overflow');
    }
  }
}

export function skip(ms = 1n) {
  if (DEBUG) info('skipping');
  currentTime += ms;
}
