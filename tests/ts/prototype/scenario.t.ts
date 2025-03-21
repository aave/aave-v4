import {LiquidityHub, Spoke, User, skip} from './core';
import {absDiff, f, maxAbsDiff, p, PRECISION} from './utils';

const hub = new LiquidityHub();
const spokes = [new Spoke(hub)];
const users = [new User(), new User(), new User()];
const [alice, bob, charlie] = users;
assignSpokesToUsers();

// // action borrow user 39n amount 4734847151.618921234706726913
// // action repay user 235n amount 9924500511.421444012921323521

// action updateRiskPremium id 441n
// skipping
// action supply id 660n amount 8564231494.874205585470914561
// action borrow id 660n amount 8564231494.874205585470914561
// skipping
// action supply id 606n amount 7268599020.805897545012215809
// action borrow id 606n amount 7268599020.805897545012215809
// action repay id 606n amount 7268599020.805897545012215809

// skipping
// action supply id 1n amount 3801340823.527060698682097665
// action borrow id 1n amount 3801340823.527060698682097665
// action repay id 1n amount 3801340823.527060698682097665
// skipping
// action borrow id 1n amount 411790791.708231892134264833
// skipping
// action borrow id 1n amount 2971796614.986197131165958145
// skipping
// action supply id 2n amount 4557790560.204579436593414145
// action borrow id 2n amount 4557790560.204579436593414145
// action repay id 2n amount 4557790560.204579436593414145

// skip();
// const a1 = p('1000');
// alice.supply(a1);
// alice.borrow(a1);
// alice.repay(a1);
// skip();
// const a2 = p('400');
// alice.borrow(a2);
// skip();
// const a3 = p('600');
// alice.borrow(a3);
// skip();
// const b1 = p('1000');
// bob.supply(b1);
// bob.borrow(b1);
// // spokes[0].log(true, true);

// console.log('bob debt', bob.getDebt());
// bob.repay(b1);
// logBaseAndPremiumDebt(bob);
// skip();

// spokes[0].log(true, true);

// const amount = p(1000);
// alice.supply(amount);
// bob.borrow(amount / 2n);
// skip();
// alice.log(true);
// bob.log(true);
// hub.log();

// skipping
// skipping
// skipping
// action supply id 18n amount 6525501895.158505512462450689
// action borrow id 18n amount 6525501895.158505512462450689
// action repay id 18n amount 6525501895.158505512462450689
// action borrow id 14n amount 1076810372.196269515648008193
// skipping
// skipping
// action supply id 14n amount 8476748790.273548272476880897
// action borrow id 14n amount 8476748790.273548272476880897
// action repay id 14n amount 8476748790.273548272476880897
const amount1 = p('1000');
alice.supply(amount1);
alice.borrow(amount1);
alice.repay(amount1);

alice.log(true, true);

const amount2 = p('1000');
bob.borrow(amount2);
skip();

const amount3 = p('1000');
bob.supply(amount3);
bob.borrow(amount3);
bob.repay(amount3);

bob.log(true, true);

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
  const hubSuppliedShares = hub.totalSuppliedShares;
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
