import {
  DEBUG,
  MAX_UINT,
  RAY,
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
} from './utils.ts';

let spokeIdCounter = 0n;
let userIdCounter = 0n;

let currentTime = 1n;

// type/token transfers to differentiate supplied/debt shares
// notify is missing
export class LiquidityHub {
  public spokes: Spoke[] = [];
  public lastUpdateTimestamp = 0n;

  public baseDrawnShares = 0n;
  public ghostDrawnShares = 0n;
  public offset = 0n;
  public unrealisedPremium = 0n;

  public totalDrawnAssets = 0n;
  public totalDrawnShares = 0n;

  public availableLiquidity = 0n;

  public totalSuppliedShares = 0n;

  // total drawn assets does not incl totalOutstandingPremium to accrue base rate separately
  toDebtAssets(shares: bigint, rounding = Rounding.FLOOR) {
    this.accrue();
    return this.totalDrawnShares
      ? mulDiv(shares, this.totalDrawnAssets, this.totalDrawnShares, rounding)
      : shares;
  }

  toDebtShares(assets: bigint, rounding = Rounding.FLOOR) {
    this.accrue();
    return this.totalDrawnAssets
      ? mulDiv(assets, this.totalDrawnShares, this.totalDrawnAssets, rounding)
      : assets;
  }

  totalOutstandingPremium(rounding = Rounding.FLOOR) {
    return (
      this.toDebtAssets(this.ghostDrawnShares, rounding) - this.offset + this.unrealisedPremium
    );
  }

  totalSupplyAssets(rounding = Rounding.FLOOR) {
    this.accrue();
    return this.availableLiquidity + this.totalDrawnAssets + this.totalOutstandingPremium(rounding);
  }

  toSupplyAssets(shares: bigint, rounding = Rounding.FLOOR) {
    return this.totalSuppliedShares
      ? mulDiv(shares, this.totalSupplyAssets(rounding), this.totalSuppliedShares, rounding)
      : shares;
  }

  toSupplyShares(assets: bigint, rounding = Rounding.FLOOR) {
    const totalSupplyAssets = this.totalSupplyAssets(rounding);
    return totalSupplyAssets
      ? mulDiv(assets, this.totalSuppliedShares, totalSupplyAssets, rounding)
      : assets;
  }

  accrue() {
    if (this.lastUpdateTimestamp === currentTime) return;
    this.lastUpdateTimestamp = currentTime;
    this.totalDrawnAssets = (this.totalDrawnAssets * randomIndex()) / RAY;
  }

  supply(amount: bigint, spoke: Spoke) {
    const suppliedShares = this.toSupplyShares(amount);
    assertNonZero(suppliedShares);

    this.totalSuppliedShares += suppliedShares;
    this.availableLiquidity += amount;

    this.getSpoke(spoke).suppliedShares += suppliedShares;

    return suppliedShares;
  }

  withdraw(amount: bigint, spoke: Spoke) {
    const suppliedShares = this.toSupplyShares(amount, Rounding.CEIL);

    this.totalSuppliedShares -= suppliedShares;
    this.availableLiquidity -= amount;

    this.getSpoke(spoke).suppliedShares -= suppliedShares;

    return suppliedShares;
  }

  // @dev spoke data is *expected* to be updated on the `refresh` callback
  draw(amount: bigint, spoke: Spoke) {
    const drawnShares = this.toDebtShares(amount, Rounding.CEIL);

    this.availableLiquidity -= amount;

    this.totalDrawnShares += drawnShares;
    this.totalDrawnAssets += amount;

    return drawnShares;
  }

  // @dev global premiumDebt (ghost, offset, unrealised) & spoke data is *expected* to be updated on the `refresh` callback
  restore(baseAmount: bigint, premiumAmount: bigint, spoke: Spoke) {
    const baseDrawnSharesRestored = this.toDebtShares(baseAmount);

    this.availableLiquidity += baseAmount + premiumAmount;

    this.totalDrawnAssets -= baseAmount;
    this.totalDrawnShares -= baseDrawnSharesRestored;

    return baseDrawnSharesRestored;
  }

  refresh(
    userBaseDrawnSharesDelta: bigint,
    userGhostDrawnSharesDelta: bigint,
    userOffsetDelta: bigint,
    userUnrealisedPremiumDelta: bigint,
    who: Spoke
  ) {
    this.baseDrawnShares += userBaseDrawnSharesDelta;
    this.ghostDrawnShares += userGhostDrawnSharesDelta;
    this.offset += userOffsetDelta;
    this.unrealisedPremium += userUnrealisedPremiumDelta;
    this.checkBounds(this);

    const spoke = this.getSpoke(who);
    spoke.baseDrawnShares += userBaseDrawnSharesDelta;
    spoke.ghostDrawnShares += userGhostDrawnSharesDelta;
    spoke.offset += userOffsetDelta;
    spoke.unrealisedPremium += userUnrealisedPremiumDelta;
    this.checkBounds(spoke);
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

  log(spokes = false) {
    const ghostDebt = this.toDebtAssets(this.ghostDrawnShares) - this.offset;
    console.log('--- Hub ---');
    console.log('hub.totalDrawnShares        ', f(this.totalDrawnShares));
    console.log('hub.totalDrawnAssets        ', f(this.totalDrawnAssets));
    console.log('hub.baseDrawnShares         ', f(this.baseDrawnShares));
    console.log('hub.ghostDrawnShares        ', f(this.ghostDrawnShares));
    console.log('hub.offset                  ', f(this.offset));
    console.log('hub.ghostDebt               ', f(ghostDebt));
    console.log('hub.unrealisedPremium       ', f(this.unrealisedPremium));

    console.log('hub.totalSuppliedShares     ', f(this.totalSuppliedShares));
    console.log('hub.totalSupplyAssets       ', f(this.totalSupplyAssets()));
    console.log('hub.availableLiquidity      ', f(this.availableLiquidity));
    console.log('hub.totalOutstandingPremium ', f(this.totalOutstandingPremium()));
    console.log('hub.lastUpdateTimestamp     ', this.lastUpdateTimestamp);

    console.log('hub.getTotalDebt            ', f(this.getTotalDebt()));
    console.log('hub.getDebt: baseDebt       ', f(this.getDebt().baseDebt));
    console.log('hub.getDebt: premiumDebt    ', f(this.getDebt().premiumDebt));
    console.log();

    if (spokes) this.spokes.forEach((spoke) => spoke.log());
  }

  getTotalDebt() {
    return Object.values(this.getDebt()).reduce((sum, debt) => sum + debt, 0n);
  }

  getDebt() {
    this.accrue();
    return {
      baseDebt: this.toDebtAssets(this.baseDrawnShares),
      premiumDebt: this.toDebtAssets(this.ghostDrawnShares) - this.offset + this.unrealisedPremium,
    };
  }

  addSpoke(who: Spoke) {
    this.spokes.push(new Spoke(this, who.id)); // clone to maintain independent accounting
  }

  checkBounds(who: Spoke | LiquidityHub = this) {
    const fail = [
      who.baseDrawnShares,
      who.ghostDrawnShares,
      who.offset,
      who.unrealisedPremium,
      ...(who instanceof LiquidityHub
        ? [
            who.totalSuppliedShares,
            who.totalSupplyAssets(),
            who.totalOutstandingPremium(),
            who.availableLiquidity,
            who.totalDrawnAssets,
            who.totalDrawnShares,
          ]
        : []),
    ].reduce((flag, v) => flag || v < 0n || v > MAX_UINT, false);
    if (fail) {
      who.log(true);
      throw new Error('underflow/overflow');
    }
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
    const drawnShares = this.hub.draw(amount, this);

    const oldUserBaseDrawnShares = user.baseDrawnShares;
    user.baseDrawnShares += drawnShares;
    user.riskPremium = randomRiskPremium();

    const oldUserGhostDrawnShares = user.ghostDrawnShares;
    const oldUserOffset = user.offset;
    const oldUserUnrealisedPremium = user.unrealisedPremium;

    user.ghostDrawnShares = percentMul(user.baseDrawnShares, user.riskPremium);
    user.offset = this.hub.toDebtAssets(user.ghostDrawnShares, Rounding.CEIL);
    user.unrealisedPremium +=
      this.hub.toDebtAssets(oldUserGhostDrawnShares, Rounding.CEIL) - oldUserOffset;

    this.refresh(
      user.baseDrawnShares - oldUserBaseDrawnShares,
      user.ghostDrawnShares - oldUserGhostDrawnShares,
      user.offset - oldUserOffset,
      user.unrealisedPremium - oldUserUnrealisedPremium,
      user
    );

    return drawnShares;
  }

  repay(amount: bigint, who: User) {
    const user = this.getUser(who);

    this.hub.accrue();
    const {baseDebt, premiumDebt} = this.getUserDebt(who);
    const {baseDebtRestored, premiumDebtRestored} = this.deductFromPremium(
      baseDebt,
      premiumDebt,
      amount,
      user
    );
    const drawnShares = this.hub.restore(baseDebtRestored, premiumDebtRestored, this);

    const oldUserBaseDrawnShares = user.baseDrawnShares;
    user.baseDrawnShares -= drawnShares;
    user.riskPremium = randomRiskPremium();

    const oldUserGhostDrawnShares = user.ghostDrawnShares;
    const oldUserOffset = user.offset;
    const oldUserUnrealisedPremium = user.unrealisedPremium;

    user.ghostDrawnShares = percentMul(user.baseDrawnShares, user.riskPremium);
    user.offset = this.hub.toDebtAssets(user.ghostDrawnShares);
    user.unrealisedPremium = premiumDebt - premiumDebtRestored;

    this.refresh(
      user.baseDrawnShares - oldUserBaseDrawnShares,
      user.ghostDrawnShares - oldUserGhostDrawnShares,
      user.offset - oldUserOffset,
      user.unrealisedPremium - oldUserUnrealisedPremium,
      user
    );

    return drawnShares;
  }

  deductFromPremium(baseDebt: bigint, premiumDebt: bigint, amount: bigint, user: User) {
    if (amount === MAX_UINT) {
      amount = baseDebt + premiumDebt;
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
    user.offset = this.hub.toDebtAssets(user.ghostDrawnShares);

    const newUnrealisedPremium = this.hub.toDebtAssets(oldUserGhostDrawnShares) - oldUserOffset;
    user.unrealisedPremium += newUnrealisedPremium;

    this.refresh(
      0n, // no change in base debt
      user.ghostDrawnShares - oldUserGhostDrawnShares,
      user.offset - oldUserOffset,
      newUnrealisedPremium,
      user
    );
  }

  refresh(
    userBaseDrawnSharesDelta: bigint,
    userGhostDrawnSharesDelta: bigint,
    userOffsetDelta: bigint,
    userUnrealisedPremiumDelta: bigint,
    user: User
  ) {
    this.checkBounds(user);

    this.baseDrawnShares += userBaseDrawnSharesDelta;
    this.ghostDrawnShares += userGhostDrawnSharesDelta;
    this.offset += userOffsetDelta;
    this.unrealisedPremium += userUnrealisedPremiumDelta;
    this.checkBounds();

    this.hub.refresh(
      userBaseDrawnSharesDelta,
      userGhostDrawnSharesDelta,
      userOffsetDelta,
      userUnrealisedPremiumDelta,
      this
    );
  }

  getTotalDebt() {
    return Object.values(this.getDebt()).reduce((sum, debt) => sum + debt, 0n);
  }

  getDebt() {
    this.hub.accrue();
    return {
      baseDebt: this.hub.toDebtAssets(this.baseDrawnShares),
      premiumDebt:
        this.hub.toDebtAssets(this.ghostDrawnShares) - this.offset + this.unrealisedPremium,
    };
  }

  getUserDebt(who: User) {
    this.hub.accrue();
    const user = this.getUser(who);
    return {
      baseDebt: this.hub.toDebtAssets(user.baseDrawnShares),
      premiumDebt:
        this.hub.toDebtAssets(user.ghostDrawnShares) - user.offset + user.unrealisedPremium,
    };
  }

  getUserTotalDebt(who: User) {
    return Object.values(this.getUserDebt(who)).reduce((sum, debt) => sum + debt, 0n);
  }

  addUser(user: User) {
    // store user reference since we don't back update since it's an eoa
    this.users.push(user);
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

  checkBounds(who: Spoke | User = this) {
    const fail = [
      who.baseDrawnShares,
      who.ghostDrawnShares,
      who.offset,
      who.unrealisedPremium,
      who.suppliedShares,
    ].reduce((flag, v) => flag || v < 0n || v > MAX_UINT, false);
    if (fail) {
      who.log(true);
      throw new Error('underflow/overflow');
    }
  }

  log(hub = false, users = false) {
    const ghostDebt = this.hub.toDebtAssets(this.ghostDrawnShares) - this.offset;
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
    this.spoke.supply(amount, this);
  }

  withdraw(amount: bigint) {
    info('action withdraw', 'id', this.id, 'amount', f(amount));
    this.spoke.withdraw(amount, this);
  }

  borrow(amount: bigint) {
    info('action borrow', 'id', this.id, 'amount', f(amount));
    this.spoke.borrow(amount, this);
  }

  repay(amount: bigint) {
    info('action repay', 'id', this.id, 'amount', f(amount));
    this.spoke.repay(amount, this);
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

  log(spoke = false, hub = false) {
    const ghostDebt = this.hub.toDebtAssets(this.ghostDrawnShares) - this.offset;
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

export function skip(ms = 1n) {
  if (DEBUG) info('skipping');
  currentTime += ms;
}
