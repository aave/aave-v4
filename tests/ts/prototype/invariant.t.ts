import {LiquidityHub, Spoke, User, skip} from './core';
import {
  random,
  randomChance,
  absDiff,
  maxAbsDiff,
  f,
  PRECISION,
  MAX_UINT,
  Rounding,
  randomAmount,
} from './utils';

// todo make random deterministic, cache seed, actions list for failed runs for debugging
const NUM_SPOKES = 10;
const NUM_USERS = 3000;
const DEPTH = 100;
const hub = new LiquidityHub();
const spokes = new Array(NUM_SPOKES).fill(0).map(() => new Spoke(hub));
const users = new Array(NUM_USERS).fill(0).map(() => new User());

const actions = ['supply', 'withdraw', 'borrow', 'repay', 'updateRiskPremium'];

assignSpokesToUsers();
const userCollateral = new Map<User, bigint>(); // without accounting for supply yield
const userDebt = new Map<User, bigint>(); // without accounting for debt interest
let totalAvailable = 0n; // without accounting for supply yield

function run() {
  for (let j = 0; j < DEPTH; j++) {
    if (randomChance(0.8)) skip();
    if (randomChance(0.25)) {
      users.forEach((user) => user.getTotalDebt() ?? user.repay(MAX_UINT));
      userDebt.clear();
      runAmountInvariants();
    }
    if (randomChance(0.25)) {
      users.forEach((user) => user.suppliedShares ?? user.withdraw(user.getSuppliedBalance()));
      userCollateral.clear();
    }

    const action = actions[Math.floor(Math.random() * actions.length)];
    const user = users[Math.floor(Math.random() * users.length)];
    let amount = randomAmount();

    switch (action) {
      case 'supply': {
        user.supply(amount);
        userCollateral.set(user, (userCollateral.get(user) || 0n) + amount);
        totalAvailable += amount;
        break;
      }
      case 'withdraw': {
        const supplied = userCollateral.get(user) || 0n;
        if (supplied < amount) {
          if (supplied === 0n) continue;
          user.supply(amount);
        } else {
          userCollateral.set(user, supplied - amount);
          totalAvailable -= amount;
        }
        user.withdraw(amount);
        break;
      }
      case 'borrow': {
        if (amount > totalAvailable) {
          if (totalAvailable < 10n ** 18n) user.supply(amount);
          else amount = random(1n, totalAvailable);
        }
        const drawn = userDebt.get(user) || 0n;
        user.borrow(amount);
        userDebt.set(user, drawn + amount);
        totalAvailable -= amount;
        break;
      }
      case 'repay': {
        let drawn = userDebt.get(user) || 0n;
        if (drawn < amount) {
          user.supply(amount);
          user.borrow(amount);
          drawn += amount;
          amount = random(1n, user.getTotalDebt());
          if (randomChance(0.5)) skip();
        }
        user.repay(amount);
        userDebt.set(user, drawn - amount);
        totalAvailable += amount;
        break;
      }
      case 'updateRiskPremium': {
        user.updateRiskPremium();
        break;
      }
    }

    runAmountInvariants();
  }

  hub.log();

  users.forEach((user) => user.repay(MAX_UINT));
  userDebt.clear();
  runAmountInvariants();

  hub.log();

  console.log(`ran ${DEPTH} iterations with ${NUM_SPOKES} spokes and ${NUM_USERS} users`);
}
run();

export function runAmountInvariants() {
  invariant_valuesWithinBounds();
  invariant_hubSpokeAccounting();
  invariant_sumOfBaseDebt();
  invariant_sumOfPremiumDebt();
  invariant_sumOfSuppliedShares();
  invariant_drawnGtSuppliedLiquidity();
}

export function assignSpokesToUsers() {
  users.forEach((user) => {
    const spoke = spokes[Math.floor(Math.random() * spokes.length)];
    user.assignSpoke(spoke);
    spoke.addUser(user);
  });
}

export function invariant_valuesWithinBounds() {
  let fail = false;
  ['baseDrawnShares', 'ghostDrawnShares', 'offset', 'unrealisedPremium', 'suppliedShares'].forEach(
    (key) => {
      [hub, ...spokes, ...users].forEach((who) => {
        if (who[key] < 0n || who[key] > MAX_UINT) {
          who.log();
          console.error(`${who}.${key} < 0 || > MAX_UINT`, f(who[key]));
          fail = true;
        }
      });
    }
  );
  handleInvariantFailure(fail, 'invariant_valuesWithinBounds');
}

export function invariant_sumOfBaseDebt() {
  let fail = false,
    diff = 0n;
  const hubBaseDebt = hub.getDebt().baseDebt;
  const spokeBaseDebt = spokes.reduce((sum, spoke) => sum + spoke.getDebt().baseDebt, 0n);
  const userBaseDebt = users.reduce((sum, user) => sum + user.getDebt().baseDebt, 0n);
  if ((diff = absDiff(hubBaseDebt, spokeBaseDebt)) > PRECISION) {
    console.error('hubBaseDebt !== spokeBaseDebt, diff', f(hubBaseDebt), f(spokeBaseDebt), diff);
    fail = true;
  }
  if ((diff = absDiff(spokeBaseDebt, userBaseDebt)) > PRECISION) {
    console.error('spokeBaseDebt !== userBaseDebt, diff', f(spokeBaseDebt), f(userBaseDebt), diff);
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

  // handleInvariantFailure(fail, arguments.callee.name);
  handleInvariantFailure(fail, 'invariant_sumOfBaseDebt');
}

export function invariant_sumOfPremiumDebt() {
  let fail = false,
    diff = 0n;
  const hubPremiumDebt = hub.getDebt().premiumDebt;
  const spokePremiumDebt = spokes.reduce((sum, spoke) => sum + spoke.getDebt().premiumDebt, 0n);
  const userPremiumDebt = users.reduce((sum, user) => sum + user.getDebt().premiumDebt, 0n);
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
  ['ghostDrawnShares', 'offset', 'unrealisedPremium'].forEach((key) => {
    const hubKey = hub[key];
    const spokeKey = spokes.reduce((sum, spoke) => sum + spoke[key], 0n);
    const userKey = users.reduce((sum, user) => sum + user[key], 0n);
    if ((diff = absDiff(hubKey, spokeKey)) > PRECISION) {
      console.error(`hub.${key} !== spoke.${key}, diff`, f(hubKey), f(spokeKey), diff);
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

  handleInvariantFailure(fail, 'invariant_sumOfPremiumDebt');
}

export function invariant_sumOfSuppliedShares() {
  const hubSuppliedShares = hub.suppliedShares;
  const spokeSuppliedShares = spokes.reduce((sum, spoke) => sum + spoke.suppliedShares, 0n);
  const userSuppliedShares = users.reduce((sum, user) => sum + user.suppliedShares, 0n);
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

  handleInvariantFailure(fail, 'invariant_sumOfSuppliedShares');
}

export function invariant_drawnGtSuppliedLiquidity() {
  let fail = false;
  const hubTotalDebt = hub.getTotalDebt();
  const hubTotalSuppliedLiquidity = hub.totalSupplyAssets();

  if (hubTotalDebt > hubTotalSuppliedLiquidity) {
    console.error(
      'hubTotalDebt <= hubTotalSuppliedLiquidity',
      f(hubTotalDebt),
      f(hubTotalSuppliedLiquidity)
    );
    fail = true;
  }

  const spokeTotalDebt = spokes.reduce((sum, spoke) => sum + spoke.getTotalDebt(), 0n);
  const spokeTotalSuppliedLiquidity = spokes.reduce(
    (sum, spoke) => sum + hub.toSupplyAssets(spoke.suppliedShares),
    0n
  );
  if (spokeTotalDebt > spokeTotalSuppliedLiquidity) {
    console.error(
      'spokeTotalDebt <= spokeTotalSuppliedLiquidity',
      f(spokeTotalDebt),
      f(spokeTotalSuppliedLiquidity)
    );
    fail = true;
  }

  const userTotalDebt = users.reduce((sum, user) => sum + user.getTotalDebt(), 0n);
  const userTotalSuppliedLiquidity = users.reduce(
    (sum, user) => sum + hub.toSupplyAssets(user.suppliedShares),
    0n
  );
  if (userTotalDebt > userTotalSuppliedLiquidity) {
    console.error(
      'userTotalDebt <= userTotalSuppliedLiquidity',
      f(userTotalDebt),
      f(userTotalSuppliedLiquidity)
    );
    fail = true;
  }

  handleInvariantFailure(fail, 'invariant_drawnGtSuppliedLiquidity');
}

export function invariant_hubSpokeAccounting() {
  let fail = false;

  spokes.forEach((spoke) => {
    const spokeOnHub = hub.getSpoke(spoke);
    [
      'baseDrawnShares',
      'ghostDrawnShares',
      'offset',
      'unrealisedPremium',
      'suppliedShares',
    ].forEach((key) => {
      if (spoke[key] !== spokeOnHub[key]) {
        console.error(
          `spoke(${spoke.id}).${key} ${f(spoke[key])} !== hub.spokes[${hub.idx(spoke)}].${key} ${f(
            spokeOnHub[key]
          )}`
        );
        fail = true;
      }
    });
  });

  handleInvariantFailure(fail, 'invariant_hubSpokeAccountingMatch');
}

export function handleInvariantFailure(fail: boolean, invariant: string) {
  if (fail) {
    // hub.log(true);
    // spokes.forEach((spoke) => spoke.log());
    // users.forEach((user) => user.log());
    throw new Error(`${invariant} failed`);
  }
}
