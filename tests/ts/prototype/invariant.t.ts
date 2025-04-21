import {User, skip, System} from './core';
import {random, randomChance, MAX_UINT, randomAmount, absDiff, f} from './utils';

// todo make random deterministic, cache seed, actions list for failed runs for debugging
const NUM_SPOKES = 10;
const NUM_USERS = 3000;
const DEPTH = 1000;

const actions = ['supply', 'withdraw', 'borrow', 'repay', 'updateRiskPremium'];

function run() {
  const usersSupplied = new Map<User, bigint>(); // without accounting for supply yield
  const usersDrawn = new Map<User, bigint>(); // without accounting for debt interest
  let totalAvailable = 0n; // without accounting for supply yield

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
        user.supply((amount = system.nonZeroSuppliedShares(amount)));
        usersSupplied.set(user, (usersSupplied.get(user) || 0n) + amount);
        totalAvailable += amount;
        break;
      }
      case 'withdraw': {
        const supplied = usersSupplied.get(user) || 0n;
        if (amount > supplied) {
          const balanceBefore = user.getSuppliedBalance();
          user.supply((amount = system.nonZeroSuppliedShares(amount)));
          const balanceAfter = user.getSuppliedBalance() - amount;
          // can have amount - 1 (or dust) supplied balance right after if debt in system due to index
          // if (sum(usersDrawn) > 0n) skip();
          // else amount -= 1n;
          amount = user.getSuppliedBalance();
          if (sum(usersDrawn) > 0 && randomChance(0.5)) skip();
          if (absDiff(balanceBefore, balanceAfter) > 1n) {
            console.log('diff > 1', f(balanceBefore), f(balanceAfter), 'sys debt', sum(usersDrawn));
          }
        } else {
          usersSupplied.set(user, supplied - amount);
          totalAvailable -= amount;
        }
        console.log('user balance', f(user.getSuppliedBalance()), 'trying to withdraw', f(amount));
        user.withdraw(amount);
        break;
      }
      case 'borrow': {
        if (amount > totalAvailable) {
          if (totalAvailable < 10n ** 18n) {
            user.supply((amount = system.nonZeroSuppliedShares(amount)));
            totalAvailable += amount;
            if (randomChance(0.5)) skip();
          } else amount = random(1n, totalAvailable);
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
          user.supply((amount = system.nonZeroSuppliedShares(amount)));
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

  system.hub.log();

  system.repayAll();
  system.withdrawAll();

  system.hub.log();

  console.log(`ran ${DEPTH} iterations with ${NUM_SPOKES} spokes and ${NUM_USERS} users`);
}

run();

function sum(map: Map<any, bigint>) {
  return Array.from(map.values()).reduce((a, b) => a + b, 0n);
}
