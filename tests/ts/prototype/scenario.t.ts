import {LiquidityHub, Spoke, User, skip} from './core';
import {absDiff, f, MAX_UINT, maxAbsDiff, p, PRECISION} from './utils';

const hub = new LiquidityHub();
const spokes = [new Spoke(hub)];
const users = [new User(), new User(), new User()];
const [alice, bob, charlie] = users;
assignSpokesToUsers();

const amount1 = p('10000');
const amount2 = p('200');
const amount3 = p('500');

alice.supply(amount1);
alice.borrow(amount1);

skip();
alice.repay(amount2);
alice.log(true, true);
bob.borrow(amount2);

skip();
alice.repay(amount3);
alice.log(true, true);
charlie.borrow(amount3);
alice.repay(amount3);

skip();
alice.log(true, true);
charlie.borrow(amount3);

skip();
alice.repay(MAX_UINT);
alice.log(true, true);

skip();
charlie.repay(MAX_UINT);

skip();
bob.repay(MAX_UINT);
bob.log(true, true);

skip();
alice.withdraw(amount2);
skip();
alice.withdraw(alice.getSuppliedBalance());

alice.log(true, true);

runAmountInvariants();

function runAmountInvariants() {
  invariant_hubSpokeAccounting();
  invariant_sumOfBaseDebt();
  invariant_sumOfPremiumDebt();
  invariant_sumOfSuppliedShares();
  invariant_drawnGtSuppliedLiquidity();
}

function assignSpokesToUsers() {
  users.forEach((user) => {
    const spoke = spokes[Math.floor(Math.random() * spokes.length)];
    user.assignSpoke(spoke);
    spoke.addUser(user);
  });
}

function invariant_sumOfBaseDebt() {
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

function invariant_sumOfPremiumDebt() {
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

function invariant_sumOfSuppliedShares() {
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
    throw new Error('invariant_sumOfSuppliedShares failed');
  }
  if ((diff = absDiff(hubSuppliedShares, userSuppliedShares)) > PRECISION) {
    console.error(
      'hubSuppliedShares !== userSuppliedShares, diff',
      f(hubSuppliedShares),
      f(userSuppliedShares),
      diff
    );
    fail = true;
    throw new Error('invariant_sumOfSuppliedShares failed');
  }

  handleInvariantFailure(fail, 'invariant_sumOfSuppliedShares');
}

function invariant_drawnGtSuppliedLiquidity() {
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
  handleInvariantFailure(fail, 'invariant_drawnGtSuppliedLiquidity');
}

function invariant_hubSpokeAccounting() {
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

function handleInvariantFailure(fail: boolean, invariant: string) {
  if (fail) {
    // hub.log(true);
    // spokes.forEach((spoke) => spoke.log());
    // users.forEach((user) => user.log());
    throw new Error(`${invariant} failed`);
  }
}
