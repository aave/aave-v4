import {LiquidityHub, Spoke, User, skip, OFFSET_UNITS} from './core';
import {absDiff, f, maxAbsDiff, p, PRECISION, MAX_UINT} from './utils';

const tests: {name: string; test: () => void}[] = [];

let hub;
let spokes;
let users;

// Test Scenario 1
// t0: supply/borrow
// t1: repay principal
// t1: repay full
addTest('Scenario1', () => {
  const [alice] = setUp();
  const amount = p('1000');

  alice.supply(amount);
  alice.borrow(amount);

  alice.log(true, true);

  alice.repay(amount);
  alice.log(true, true);

  alice.repay(MAX_UINT);

  runAmountInvariants();
  assert_zeroRemainingDebt();
});

// Test Scenario 2
// t0: alice supply/borrow
// t1: alice repay full; bob borrow
// t2: bob repay full
// t3: charlie borrow
// t4: charlie repay full
addTest('Scenario2', () => {
  const [alice, bob, charlie] = setUp();

  const amount1 = p('1000');
  alice.supply(amount1);
  alice.borrow(amount1);

  alice.log(true, true);

  skip();

  alice.log(true, true);
  alice.repay(MAX_UINT);
  alice.log(true, true);

  const amount2 = p('1000');
  bob.borrow(amount2);
  skip();

  // bob.log(true, true);
  bob.repay(MAX_UINT);

  skip();
  const amount4 = p('700');
  charlie.borrow(amount4);

  skip();
  // charlie.log(true, true);
  charlie.repay(amount4);
  charlie.log(true, true);

  skip();
  // charlie.log(true, true);
  charlie.repay(MAX_UINT);
  // charlie.log(true, true);

  runAmountInvariants();
  assert_zeroRemainingDebt();
});

// Test Scenario 3
// t0: alice supply/borrow
// t1: alice repay partial; bob borrow
// t2: alice repay partial; charlie borrow; alice repay partial
// t3: charlie borrow
// t4: alice repay full
// t5: charlie repay full
// t6: bob repay full
addTest('Scenario3', () => {
  const [alice, bob, charlie] = setUp();

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

  runAmountInvariants();
  assert_zeroRemainingDebt();
});

// Test Scenario 4 - withdraw
// t0: alice supply/borrow
// 
addTest('Scenario4', () => {
  const [alice, bob, charlie] = setUp();

  const amount1 = p('10000');
  const amount2 = p('200');
  const amount3 = p('500');
  const amount4 = p('800');

  alice.supply(amount1);
  
  skip();
  bob.borrow(amount2);
  bob.supply(amount3);

  skip();
  charlie.supply(amount3);
  charlie.borrow(amount2);

  skip();
  alice.withdraw(MAX_UINT);

  skip();
  bob.withdraw(MAX_UINT);

  skip();
  charlie.repay(MAX_UINT);
  bob.repay(MAX_UINT);

  skip();
  charlie.withdraw(MAX_UINT);
  bob.withdraw(MAX_UINT);
  alice.withdraw(MAX_UINT);

  runAmountInvariants();
  assert_zeroRemainingSuppliedShares();
});

// run all tests
runAllTests();

function setUp() {
  hub = new LiquidityHub();
  spokes = [new Spoke(hub)];
  users = [new User(), new User(), new User()];

  assignSpokesToUsers();

  return users;
}

function addTest(name: string, test: () => void) {
  tests.push({name, test});
}

function runAllTests() {
  tests.forEach(({name, test}) => {
    console.log(`\n--- Running Test: ${name} ---`);
    test();
  });
}

function runAmountInvariants() {
  console.log('...running invariants...');
  invariant_hubSpokeAccounting();
  invariant_sumOfBaseDebt();
  invariant_sumOfPremiumDebt();
  invariant_sumOfSuppliedShares();
  invariant_drawnGtSuppliedLiquidity();
  invariant_positivePremiumDebt();
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

function assert_zeroRemainingSuppliedShares() {
  const hubSuppliedShares = hub.suppliedShares;
  const spokeSuppliedShares = spokes.reduce((sum, spoke) => sum + spoke.suppliedShares, 0n);
  const userSuppliedShares = users.reduce((sum, user) => sum + user.suppliedShares, 0n);
  let fail = false;
  const supplySharePrecision = hub.toSupplyShares(OFFSET_UNITS);

  if (hubSuppliedShares > supplySharePrecision || spokeSuppliedShares > supplySharePrecision || userSuppliedShares > supplySharePrecision) {
    console.error(
      'non zero supplied shares',
      f(hubSuppliedShares),
      f(spokeSuppliedShares),
      f(userSuppliedShares),
      f(supplySharePrecision)
    );
    fail = true;
    throw new Error('assert_zeroRemainingSuppliedShares failed');
  }

  handleInvariantFailure(fail, 'assert_zeroRemainingSuppliedShares');
}

function invariant_positivePremiumDebt() {
  const hubPremiumDebt = hub.getDebt().premiumDebt;
  const spokePremiumDebt = spokes.reduce((sum, spoke) => sum + spoke.getDebt().premiumDebt, 0n);
  const userPremiumDebt = users.reduce((sum, user) => sum + user.getDebt().premiumDebt, 0n);
  let fail = false;
  if (hubPremiumDebt < 0n || spokePremiumDebt < 0n || userPremiumDebt < 0n) {
    console.error(
      'hubPremiumDebt || spokePremiumDebt || userPremiumDebt < 0',
      f(hubPremiumDebt),
      f(spokePremiumDebt),
      f(userPremiumDebt)
    );
    fail = true;
    throw new Error('invariant_positivePremiumDebt failed');
  }

  handleInvariantFailure(fail, 'invariant_positivePremiumDebt');
}


function assert_zeroRemainingDebt() {
  console.log('...assert zero remaining debt');

  const hubPremiumDebt = hub.getDebt().premiumDebt;
  const spokePremiumDebt = spokes.reduce((sum, spoke) => sum + spoke.getDebt().premiumDebt, 0n);
  const userPremiumDebt = users.reduce((sum, user) => sum + user.getDebt().premiumDebt, 0n);

  const hubBaseDebt = hub.getDebt().baseDebt;
  const spokeBaseDebt = spokes.reduce((sum, spoke) => sum + spoke.getDebt().baseDebt, 0n);
  const userBaseDebt = users.reduce((sum, user) => sum + user.getDebt().baseDebt, 0n);
  let fail = false;

  // premium debt should be exactly 0 
  if (spokePremiumDebt > 0n || userPremiumDebt > 0n || hubPremiumDebt > 0n) {
    console.error(
      'hubPremiumDebt || spokePremiumDebt || userPremiumDebt > 0n',
      f(hubPremiumDebt),
      f(spokePremiumDebt),
      f(userPremiumDebt)
    );
    fail = true;
    throw new Error('assert_zeroRemainingDebt failed');
  }

  // base debt will be within precision due to offset from inflation mitigation
  if (spokeBaseDebt > PRECISION || userBaseDebt > PRECISION || hubBaseDebt > PRECISION) {
    console.error(
      'hubPremiumDebt || spokePremiumDebt || userPremiumDebt > PRECISION',
      f(hubPremiumDebt),
      f(spokePremiumDebt),
      f(userPremiumDebt)
    );
    fail = true;
    throw new Error('assert_zeroRemainingDebt failed');
  }

  handleInvariantFailure(fail, 'assert_zeroRemainingDebt');
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
