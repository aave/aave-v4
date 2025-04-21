import {skip} from './core';
import {
  f,
  MAX_UINT,
  p,
  it,
  runScenarios,
  randomIndex,
  rayDiv,
  rayMul,
  Rounding,
  absDiff,
} from './utils';

it()((ctx) => {
  const [alice, bob, charlie] = ctx.users;
  const amount1 = p('10000');
  const amount2 = p('200');
  const amount3 = p('500');

  alice.supply(amount1);
  alice.borrow(amount1);
  skip();
  alice.repay(amount2);
  bob.borrow(amount2);
  skip();
  alice.repay(amount3);
  charlie.borrow(amount3);
  alice.repay(amount3);
  skip();
  charlie.borrow(amount3);
  skip();
  alice.repay(MAX_UINT);
  skip();
  charlie.repay(MAX_UINT);
  skip();
  bob.repay(MAX_UINT);
  skip();
  alice.withdraw(amount2);
  skip();
  alice.withdraw(alice.getSuppliedBalance());

  alice.log(true, true);
});

it()((ctx) => {
  const [alice] = ctx.users;
  const amount = p(1000);

  alice.supply(amount);
  alice.borrow(amount);

  alice.log(true, true);

  alice.repay(amount);
  alice.log(true, true);

  alice.repay(MAX_UINT);
});

it()((ctx) => {
  const [alice, bob, charlie] = ctx.users;

  const amount1 = p('1000');
  alice.supply(amount1);
  alice.borrow(amount1);

  skip();

  alice.log(true, true);
  alice.repay(MAX_UINT);
  alice.log(true, true);

  const amount2 = p('1000');
  bob.borrow(amount2);
  skip();

  bob.repay(MAX_UINT);

  skip();
  const amount4 = p('700');
  charlie.borrow(amount4);

  skip();
  charlie.repay(amount4);
  charlie.log(true, true);

  skip();
  // charlie.log(true, true);
  charlie.repay(MAX_UINT);
  // charlie.log(true, true);
});

it()((ctx) => {
  const [alice, bob, charlie] = ctx.users;

  const amount1 = p('10000');
  const amount2 = p('200');
  const amount3 = p('500');

  alice.supply(amount1);
  alice.borrow(amount1);

  skip();
  alice.repay(amount2);
  bob.borrow(amount2);

  alice.updateRiskPremium();

  skip();
  alice.repay(amount3);
  charlie.borrow(amount3);
  alice.repay(amount3);

  skip();
  charlie.borrow(amount3);

  skip();
  alice.repay(MAX_UINT);

  skip();
  charlie.repay(MAX_UINT);

  skip();
  bob.repay(MAX_UINT);
});

it()((ctx) => {
  const [alice, bob, charlie] = ctx.users;

  const amount1 = p('10000');
  const amount2 = p('200');
  const amount3 = p('500');

  alice.supply(amount1);

  skip();
  bob.borrow(amount2);
  bob.supply(amount3);

  skip();
  charlie.supply(amount3);
  charlie.borrow(amount2);

  skip();
  charlie.repay(MAX_UINT);
  bob.repay(MAX_UINT);

  skip();
  charlie.withdraw(MAX_UINT);
  bob.withdraw(MAX_UINT);
  alice.withdraw(MAX_UINT);

  alice.supply(amount1);

  skip();
  bob.borrow(amount2);
  bob.supply(amount3);

  skip();
  charlie.supply(amount3);
  charlie.borrow(amount2);

  skip();
  charlie.repay(MAX_UINT);
  bob.repay(MAX_UINT);

  skip();
  charlie.withdraw(MAX_UINT);
  bob.withdraw(MAX_UINT);
  alice.withdraw(MAX_UINT);
});

it('6 supply yields -1 bc of index').skip((ctx) => {
  const [alice, bob] = ctx.users;
  const amount = p(100);
  const amount2 = p(500);

  bob.supply(amount2);
  // skip();
  bob.withdraw(amount2 / 2n);
  // skip();
  bob.borrow(amount2 / 2n);

  alice.supply(amount);
  // skip();
  console.log('alice supplied amount', f(alice.getSuppliedBalance()), f(amount));
  try {
    alice.withdraw(amount);
  } catch (e) {
    if (!e.message.includes('suppliedShares < 0 || > MAX_UINT')) throw e;
  }
  // alice.withdraw(alice.getSuppliedBalance());
});

it('7 underflow bc sum of scaled may not to equate to individual scaled when all are unscaled')(
  (ctx) => {
    const [alice, bob, carol] = ctx.users;
    alice.supply(47168n);

    bob.borrow(22592n);
    alice.borrow(12739n);

    carol.borrow(11837n);

    skip();

    bob.repay(1714n);
    alice.repay(9n);

    carol.repay(1255n);
  }
);

it('index')((ctx) => {
  const index = randomIndex(); // 1645169034437660970422632448n, 1370571970449003121502846976n
  console.log('index', index);
  const scale = (amount: bigint) => rayDiv(amount, index, Rounding.CEIL);
  const unscale = (scaled: bigint) => rayMul(scaled, index, Rounding.CEIL); // toggle

  const amountA = 23232n;
  const scaledA = scale(amountA);
  console.log('unscaled A     ', unscale(scaledA), amountA);

  const amountB = 3243n;
  const scaledB = scale(amountB);
  console.log('unscaled B     ', unscale(scaledB), amountB);

  console.log('unscaled global', unscale(scaledA + scaledB), amountA + amountB);
  console.log('unscaled sum   ', unscale(scaledA) + unscale(scaledB), amountA + amountB);
});

it().skip((ctx) => {
  const [alice, bob] = ctx.users;
  const amount = p('0.176772459072625441');
  alice.supply(amount);
  alice.borrow(amount);

  skip();

  alice.repay(p('0.021185397759087569'));

  console.log('alice balance', f(alice.getSuppliedBalance()));
  alice.withdraw(p('0.437902789221420415'));
});

it('repay deduction')((ctx) => {
  const [alice] = ctx.users;
  const amount = p('0.000000001620580722');
  alice.supply(amount);
  alice.borrow(amount);

  skip();

  const aliceDebtBefore = alice.getTotalDebt();
  alice.repay(amount / 2n);
  const delta = aliceDebtBefore - alice.getTotalDebt();
  console.log('restored actual', f(delta), 'expected', f(amount / 2n), 'diff', delta - amount / 2n);
});

runScenarios();
