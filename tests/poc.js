var index = 10n ** 27n;

// A USER CAN ONLY WORK IN ONE SINGLE SPOKE AT A TIME
var users = [
  {
    i: 0n,
    baseDebt: 0n,
    ghostDebt: 0n,
    offset: 0n,
    rp: 0n,
  },
  {
    i: 1n,
    baseDebt: 0n,
    ghostDebt: 0n,
    offset: 0n,
    rp: 0n,
  },
  {
    i: 2n,
    baseDebt: 0n,
    ghostDebt: 0n,
    offset: 0n,
    rp: 0n,
  },
];

var spokes = [
  {
    i: 0n,
    baseDebt: 0n,
    ghostDebt: 0n,
    offset: 0n,
  },
  {
    i: 1n,
    baseDebt: 0n,
    ghostDebt: 0n,
    offset: 0n,
  },
];

var hub = {
  baseDebt: 0n,
  ghostDebt: 0n,
  offset: 0n,
};

function accrueHub(
  oldUserBaseDebt,
  oldUserGhostDebt,
  oldUserOffset,
  newUserBaseDebt,
  newUserGhostDebt,
  newUserOffset
) {
  hub.baseDebt -= oldUserBaseDebt;
  hub.ghostDebt -= oldUserGhostDebt;
  hub.offset -= oldUserOffset;
  hub.ghostDebt += newUserGhostDebt;
  hub.offset += newUserOffset;
  hub.baseDebt += newUserBaseDebt;
}

function accrueSpoke(
  spoke,
  oldUserBaseDebt,
  oldUserGhostDebt,
  oldUserOffset,
  newUserBaseDebt,
  newUserGhostDebt,
  newUserOffset
) {
  spoke.baseDebt -= oldUserBaseDebt;
  spoke.ghostDebt -= oldUserGhostDebt;
  spoke.offset -= oldUserOffset;
  spoke.baseDebt += newUserBaseDebt;
  spoke.ghostDebt += newUserGhostDebt;
  spoke.offset += newUserOffset;
}

function accrueUser(user) {
  user.baseDebt += user.ghostDebt - toScaled(user.offset); // we add the outstanding premium
  user.ghostDebt = (user.baseDebt * user.rp) / 10000n;
  user.offset = toUnscaled(user.ghostDebt);
}

function accrueIndex(accrual) {
  oldIndex = index;
  index = (index * accrual) / 10n ** 27n;
  console.log("index increases ", oldIndex, " -> ", index);
}

function accrue(spoke, user) {
  console.log("- accrue user ", user.i);
  oldUserBaseDebt = user.baseDebt;
  oldUserGhostDebt = user.ghostDebt;
  oldUserOffset = user.offset;

  accrueUser(user);
  accrueSpoke(
    spoke,
    oldUserBaseDebt,
    oldUserGhostDebt,
    oldUserOffset,
    user.baseDebt,
    user.ghostDebt,
    user.offset
  );
  accrueHub(
    oldUserBaseDebt,
    oldUserGhostDebt,
    oldUserOffset,
    user.baseDebt,
    user.ghostDebt,
    user.offset
  );
}

function logUser(user) {
  console.log("user", user.i);
  console.log("rp", user.rp);
  console.log(
    "baseDebt",
    user.baseDebt,
    " (unscaled ",
    toUnscaled(user.baseDebt),
    ")"
  );
  console.log(
    "ghostDebt",
    user.ghostDebt,
    " (unscaled ",
    toUnscaled(user.ghostDebt),
    ")"
  );
  console.log("offset", user.offset);
  console.log("");
}

function log() {
  console.log("spoke1 baseDebt", spokes[0].baseDebt);
  console.log("spoke1 ghostDebt", spokes[0].ghostDebt);
  console.log("spoke1 offset", spokes[0].offset);
  console.log("spoke2 baseDebt", spokes[1].baseDebt);
  console.log("spoke2 ghostDebt", spokes[1].ghostDebt);
  console.log("spoke2 offset", spokes[1].offset);
  console.log("hub baseDebt", hub.baseDebt);
  console.log("hub ghostDebt", hub.ghostDebt);
  console.log("hub offset", hub.offset);
}

function borrow(spoke, user, amount) {
  console.log(
    "- user ",
    user.i,
    " borrows ",
    amount,
    "(scaled ",
    toScaled(amount),
    ") in spoke ",
    spoke.i
  );

  accrue(spoke, user);

  let oldUserBaseDebt = user.baseDebt;
  let oldUserGhostDebt = user.ghostDebt;
  let oldUserOffset = user.offset;

  user.baseDebt += toScaled(amount);
  user.ghostDebt = (user.baseDebt * user.rp) / 10000n;
  user.offset += (amount * user.rp) / 10000n;

  accrueSpoke(
    spoke,
    oldUserBaseDebt,
    oldUserGhostDebt,
    oldUserOffset,
    user.baseDebt,
    user.ghostDebt,
    user.offset
  );
  accrueHub(
    oldUserBaseDebt,
    oldUserGhostDebt,
    oldUserOffset,
    user.baseDebt,
    user.ghostDebt,
    user.offset
  );
}

function repay(spoke, user, amount) {
  console.log(
    "- user ",
    user.i,
    " repays ",
    amount,
    "(scaled ",
    toScaled(amount),
    ") in spoke ",
    spoke.i
  );

  accrue(spoke, user);

  let oldUserBaseDebt = user.baseDebt;
  let oldUserGhostDebt = user.ghostDebt;
  let oldUserOffset = user.offset;

  user.baseDebt -= toScaled(amount);
  user.ghostDebt = (user.baseDebt * user.rp) / 10000n;
  user.offset -= (amount * user.rp) / 10000n;

  accrueSpoke(
    spoke,
    oldUserBaseDebt,
    oldUserGhostDebt,
    oldUserOffset,
    user.baseDebt,
    user.ghostDebt,
    user.offset
  );
  accrueHub(
    oldUserBaseDebt,
    oldUserGhostDebt,
    oldUserOffset,
    user.baseDebt,
    user.ghostDebt,
    user.offset
  );
}

function getter(user) {
  console.log("user ", user.i);
  console.log(
    "scaledTotalDebt ",
    user.baseDebt + user.ghostDebt - toScaled(user.offset)
  );
  console.log(
    "totalDebt ",
    toUnscaled(user.baseDebt + user.ghostDebt) - user.offset
  );
  console.log("");
}

function toUnscaled(amount) {
  return (amount * index) / 10n ** 27n;
}
function toScaled(amount) {
  return (amount * 10n ** 27n) / index;
}

function getTotalDebt(user) {
  return toUnscaled(user.baseDebt + user.ghostDebt) - user.offset;
}

//
// Scenario
//

users[0].rp = 2000n;
users[1].rp = 6000n;
users[2].rp = 4500n;

// User 0 in Spoke 0
borrow(spokes[0], users[0], 1000n * 10n ** 18n);
logUser(users[0]);

accrueIndex(11n * 10n ** 26n);
getter(users[0]);
accrue(spokes[0], users[0]);
logUser(users[0]);

borrow(spokes[0], users[0], 1000n * 10n ** 18n);
logUser(users[0]);

accrueIndex(11n * 10n ** 26n);
getter(users[0]);
accrue(spokes[0], users[0]);
getter(users[0]);

logUser(users[0]);
log();

repay(spokes[0], users[0], 1000n * 10n ** 18n);

logUser(users[0]);
log();

// User 1 in Spoke 1
borrow(spokes[1], users[1], 500n * 10n ** 18n);
accrueIndex(11n * 10n ** 26n);
logUser(users[1]);

repay(spokes[1], users[1], 500n * 10n ** 18n);
logUser(users[1]);

logUser(users[0]);
log();

// User 2 in Spoke 1
borrow(spokes[1], users[2], 500n * 10n ** 18n);
accrueIndex(11n * 10n ** 26n);
logUser(users[2]);

accrueIndex(11n * 10n ** 26n);

repay(spokes[1], users[2], 500n * 10n ** 18n);
logUser(users[2]);

accrueIndex(11n * 10n ** 26n);

// repay all
accrue(spokes[0], users[0]);
accrue(spokes[1], users[1]);
accrue(spokes[1], users[2]);
logUser(users[0]);

repay(spokes[0], users[0], getTotalDebt(users[0]));
repay(spokes[1], users[1], getTotalDebt(users[1]));
repay(spokes[1], users[2], getTotalDebt(users[2]));
logUser(users[0]);
logUser(users[1]);
logUser(users[2]);
log();
