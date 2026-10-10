import {test} from 'bun:test';
import {User, skip, System} from './core';
import {random, randomChance, MAX_UINT, randomAmount, absDiff, f} from './utils';

const NUM_SPOKES = 3;
const NUM_USERS = 10;
const DEPTH = 200;

const actions = ['supply', 'withdraw', 'borrow', 'repay', 'updateRiskPremium'];

test(
  `invariant fuzz (${DEPTH} iterations, ${NUM_SPOKES} spokes, ${NUM_USERS} users)`,
  () => {
    const usersSupplied = new Map<User, bigint>();
    const usersDrawn = new Map<User, bigint>();
    let totalAvailable = 0n;

    const system = new System(NUM_SPOKES, NUM_USERS);

    for (let j = 0; j < DEPTH; j++) {
      if (randomChance(0.65)) skip();
      if (randomChance(0.25)) {
        system.repayAll();
        usersDrawn.clear();
      }
      if (randomChance(0.25)) {
        system.withdrawAll();
        usersSupplied.clear();
      }

      const action = actions[Math.floor(Math.random() * actions.length)];
      const user = system.users[Math.floor(Math.random() * system.users.length)];
      let amount = randomAmount();

      switch (action) {
        case 'supply': {
          user.supply((amount = system.nonZeroAddedShares(amount)));
          usersSupplied.set(user, (usersSupplied.get(user) || 0n) + amount);
          totalAvailable += amount;
          break;
        }
        case 'withdraw': {
          const supplied = usersSupplied.get(user) || 0n;
          if (amount > supplied) {
            const balanceBefore = user.getSuppliedBalance();
            user.supply((amount = system.nonZeroAddedShares(amount)));
            const balanceAfter = user.getSuppliedBalance() - amount;
            amount = user.getSuppliedBalance();
            if (sum(usersDrawn) > 0 && randomChance(0.5)) skip();
            if (absDiff(balanceBefore, balanceAfter) > 1n) {
              console.log(
                'diff > 1',
                f(balanceBefore),
                f(balanceAfter),
                'sys debt',
                sum(usersDrawn)
              );
            }
          } else {
            usersSupplied.set(user, supplied - amount);
            totalAvailable -= amount;
          }
          console.log(
            'user balance',
            f(user.getSuppliedBalance()),
            'trying to withdraw',
            f(amount)
          );
          user.withdraw(amount);
          break;
        }
        case 'borrow': {
          if (amount > totalAvailable) {
            if (totalAvailable < 10n ** 18n) {
              user.supply((amount = system.nonZeroAddedShares(amount)));
              totalAvailable += amount;
              if (randomChance(0.5)) skip();
            } else amount = random(1n, totalAvailable);
          }
          if (amount > system.hub.liquidity) {
            if (system.hub.liquidity === 0n) break;
            amount = random(1n, system.hub.liquidity);
          }
          const drawn = usersDrawn.get(user) || 0n;
          user.borrow(amount);
          usersDrawn.set(user, drawn + amount);
          totalAvailable -= amount;
          break;
        }
        case 'repay': {
          let drawn = usersDrawn.get(user) || 0n;
          if (drawn < amount) {
            user.supply((amount = system.nonZeroAddedShares(amount)));
            user.borrow(amount);
            drawn += amount;
            amount = random(1n, user.getTotalDebt());
            if (randomChance(0.5)) skip();
          }
          user.repay(amount);
          usersDrawn.set(user, drawn - amount);
          totalAvailable += amount;
          break;
        }
        case 'updateRiskPremium': {
          user.updateRiskPremium();
          break;
        }
      }

      system.runInvariants();
    }

    system.repayAll();
    system.withdrawAll();
  },
  120_000
);

function sum(map: Map<any, bigint>) {
  return Array.from(map.values()).reduce((a, b) => a + b, 0n);
}
