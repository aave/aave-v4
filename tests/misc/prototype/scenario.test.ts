import {describe, test} from 'bun:test';
import {System, skip} from './core';
import {
  f,
  MAX_UINT,
  p,
  randomIndex,
  rayDiv,
  rayMul,
  Rounding,
  absDiff,
} from './utils';

function scenario(name: string, numSpokes = 1, numUsers = 3) {
  return (fn: (ctx: System) => void) => {
    test(name, () => {
      const ctx = new System(numSpokes, numUsers);
      fn(ctx);
      ctx.runInvariants();
    });
  };
}

describe('scenarios', () => {
  scenario('supply borrow repay withdraw multi-user')((ctx) => {
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
  });

  scenario('supply borrow repay single user')((ctx) => {
    const [alice] = ctx.users;
    const amount = p(1000);

    alice.supply(amount);
    alice.borrow(amount);
    alice.repay(amount);
    alice.repay(MAX_UINT);
  });

  scenario('sequential borrow repay across users')((ctx) => {
    const [alice, bob, charlie] = ctx.users;

    const amount1 = p('1000');
    alice.supply(amount1);
    alice.borrow(amount1);

    skip();

    alice.repay(MAX_UINT);

    const amount2 = p('1000');
    bob.borrow(amount2);
    skip();

    bob.repay(MAX_UINT);

    skip();
    const amount4 = p('700');
    charlie.borrow(amount4);

    skip();
    charlie.repay(amount4);

    skip();
    charlie.repay(MAX_UINT);
  });

  scenario('risk premium update mid-flow')((ctx) => {
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

  scenario('full cycle supply borrow repay withdraw twice')((ctx) => {
    const [alice, bob, charlie] = ctx.users;

    const amount1 = p('10000');
    const amount2 = p('200');
    const amount3 = p('500');

    for (let i = 0; i < 2; i++) {
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
    }
  });

  test.skip('supply yields -1 bc of index', () => {
    const ctx = new System(1, 3);
    const [alice, bob] = ctx.users;
    const amount = p(100);
    const amount2 = p(500);

    bob.supply(amount2);
    bob.withdraw(amount2 / 2n);
    bob.borrow(amount2 / 2n);

    alice.supply(amount);
    try {
      alice.withdraw(amount);
    } catch (e: any) {
      if (!e.message.includes('addedShares') && !e.message.includes('underflow')) throw e;
    }
  });

  scenario('underflow bc sum of scaled may not equate to individual scaled')((ctx) => {
    const [alice, bob, carol] = ctx.users;
    alice.supply(47168n);

    bob.borrow(22592n);
    alice.borrow(12739n);

    carol.borrow(11837n);

    skip();

    bob.repay(1714n);
    alice.repay(9n);

    carol.repay(1255n);
  });

  test('index scaling roundtrip', () => {
    const index = randomIndex();
    const scale = (amount: bigint) => rayDiv(amount, index, Rounding.CEIL);
    const unscale = (scaled: bigint) => rayMul(scaled, index, Rounding.CEIL);

    const amountA = 23232n;
    const scaledA = scale(amountA);
    // ceil(ceil(a / idx) * idx) >= a
    if (unscale(scaledA) < amountA) throw new Error('unscale(scale(a)) < a');

    const amountB = 3243n;
    const scaledB = scale(amountB);
    if (unscale(scaledB) < amountB) throw new Error('unscale(scale(b)) < b');
  });

  test.skip('withdraw more than supplied', () => {
    const ctx = new System(1, 3);
    const [alice] = ctx.users;
    const amount = p('0.176772459072625441');
    alice.supply(amount);
    alice.borrow(amount);

    skip();

    alice.repay(p('0.021185397759087569'));
    alice.withdraw(p('0.437902789221420415'));
  });

  scenario('repay deduction accuracy')((ctx) => {
    const [alice] = ctx.users;
    const amount = p('0.000000001620580722');
    alice.supply(amount);
    alice.borrow(amount);

    skip();

    const aliceDebtBefore = alice.getTotalDebt();
    alice.repay(amount / 2n);
    const delta = aliceDebtBefore - alice.getTotalDebt();
    if (absDiff(delta, amount / 2n) > 1n) {
      throw new Error(`repay deduction off by ${delta - amount / 2n}`);
    }
  });
});
