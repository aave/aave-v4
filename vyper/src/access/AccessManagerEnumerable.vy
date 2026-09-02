# pragma version 0.5.0b1

# Native Vyper implementation of Aave V4's enumerable AccessManager.  The
# protocol uses immediate role administration; delayed-operation entrypoints
# are included for ABI compatibility and use the same operation identifiers.

MAX_ITEMS: constant(uint256) = 1024
MAX_SELECTORS: constant(uint256) = 256
MAX_LABEL: constant(uint256) = 128
MAX_CALLDATA: constant(uint256) = 32768
MAX_RETURN: constant(uint256) = 32768

ADMIN_ROLE: public(constant(uint64)) = 0
PUBLIC_ROLE: public(constant(uint64)) = max_value(uint64)

struct Access:
    since: uint48
    delay: uint32

struct Schedule:
    timepoint: uint48
    nonce: uint32

interface IAccessManaged:
    def isConsumingScheduledOp() -> bytes4: view

event OperationScheduled:
    operationId: indexed(bytes32)
    nonce: indexed(uint32)
    schedule: uint48
    caller: address
    target: address
    data: Bytes[MAX_CALLDATA]

event OperationExecuted:
    operationId: indexed(bytes32)
    nonce: indexed(uint32)

event OperationCanceled:
    operationId: indexed(bytes32)
    nonce: indexed(uint32)

event RoleLabel:
    roleId: indexed(uint64)
    label: String[MAX_LABEL]

event RoleGranted:
    roleId: indexed(uint64)
    account: indexed(address)
    delay: uint32
    since: uint48
    newMember: bool

event RoleRevoked:
    roleId: indexed(uint64)
    account: indexed(address)

event RoleAdminChanged:
    roleId: indexed(uint64)
    admin: indexed(uint64)

event RoleGuardianChanged:
    roleId: indexed(uint64)
    guardian: indexed(uint64)

event RoleGrantDelayChanged:
    roleId: indexed(uint64)
    delay: uint32
    since: uint48

event TargetClosed:
    target: indexed(address)
    closed: bool

event TargetFunctionRoleUpdated:
    target: indexed(address)
    selector: bytes4
    roleId: indexed(uint64)

event TargetAdminDelayUpdated:
    target: indexed(address)
    delay: uint32
    since: uint48

role_access: HashMap[uint64, HashMap[address, Access]]
role_admin: HashMap[uint64, uint64]
role_guardian: HashMap[uint64, uint64]
role_grant_delay: HashMap[uint64, uint32]

target_closed: HashMap[address, bool]
target_admin_delay: HashMap[address, uint32]
target_roles: HashMap[address, HashMap[bytes4, uint64]]

schedules: HashMap[bytes32, Schedule]
execution_id: transient(bytes32)

roles: HashMap[uint256, uint64]
roles_count: uint256
role_index: HashMap[uint64, uint256]
admin_roles: HashMap[uint256, uint64]
admin_roles_count: uint256
admin_role_index: HashMap[uint64, uint256]
admin_managed_roles: HashMap[uint64, HashMap[uint256, uint64]]
admin_managed_roles_count: HashMap[uint64, uint256]
admin_managed_index: HashMap[uint64, HashMap[uint64, uint256]]

role_members: HashMap[uint64, HashMap[uint256, address]]
role_members_count: HashMap[uint64, uint256]
role_member_index: HashMap[uint64, HashMap[address, uint256]]

role_targets: HashMap[uint64, HashMap[uint256, address]]
role_targets_count: HashMap[uint64, uint256]
role_target_index: HashMap[uint64, HashMap[address, uint256]]
role_target_selectors: HashMap[uint64, HashMap[address, HashMap[uint256, bytes4]]]
role_target_selectors_count: HashMap[uint64, HashMap[address, uint256]]
role_target_selector_index: HashMap[uint64, HashMap[address, HashMap[bytes4, uint256]]]
tracked_selector_role: HashMap[address, HashMap[bytes4, uint64]]

labels: HashMap[uint256, String[MAX_LABEL]]
labels_count: uint256
label_index: HashMap[bytes32, uint256]
role_label: HashMap[uint64, String[MAX_LABEL]]
label_role: HashMap[bytes32, uint64]


@deploy
def __init__(initialAdmin: address):
    if initialAdmin == empty(address):
        raw_revert(concat(method_id("AccessManagerInvalidInitialAdmin(address)"), convert(initialAdmin, bytes32)))
    since: uint48 = convert(max(block.timestamp, 1), uint48)
    self.role_access[ADMIN_ROLE][initialAdmin] = Access(since=since, delay=0)
    self.role_members[ADMIN_ROLE][0] = initialAdmin
    self.role_members_count[ADMIN_ROLE] = 1
    self.role_member_index[ADMIN_ROLE][initialAdmin] = 1
    log RoleGranted(roleId=ADMIN_ROLE, account=initialAdmin, delay=0, since=since, newMember=True)


@internal
@view
def _has_role(role_id: uint64, account: address) -> (bool, uint32):
    if role_id == PUBLIC_ROLE:
        return True, 0
    access: Access = self.role_access[role_id][account]
    return access.since != 0 and convert(access.since, uint256) <= block.timestamp, access.delay


@internal
@view
def _require_role(role_id: uint64):
    member: bool = False
    _delay: uint32 = 0
    member, _delay = self._has_role(role_id, msg.sender)
    if not member or _delay != 0:
        raw_revert(
            concat(
                method_id("AccessManagerUnauthorizedAccount(address,uint64)"),
                convert(msg.sender, bytes32),
                convert(role_id, bytes32),
            )
        )


@internal
@view
def _require_admin():
    if msg.sender == self and len(msg.data) >= 4:
        selector: bytes4 = convert(slice(msg.data, 0, 4), bytes4)
        if self.execution_id == keccak256(concat(convert(self, bytes32), convert(selector, bytes32))):
            return
    self._require_role(ADMIN_ROLE)


@internal
@view
def _can_call_data(caller: address, target: address, data: Bytes[MAX_CALLDATA]) -> (bool, uint32):
    if len(data) < 4 or self.target_closed[target]:
        return False, 0
    selector: bytes4 = convert(slice(data, 0, 4), bytes4)
    role_id: uint64 = self.target_roles[target][selector]
    if target == self:
        role_id = ADMIN_ROLE
    member: bool = False
    delay: uint32 = 0
    member, delay = self._has_role(role_id, caller)
    if not member:
        return False, 0
    return delay == 0, delay


@internal
def _consume_schedule(operation_id: bytes32) -> uint32:
    schedule_data: Schedule = self.schedules[operation_id]
    if schedule_data.timepoint == 0:
        raw_revert(concat(method_id("AccessManagerNotScheduled(bytes32)"), operation_id))
    if convert(schedule_data.timepoint, uint256) > block.timestamp:
        raw_revert(concat(method_id("AccessManagerNotReady(bytes32)"), operation_id))
    if convert(schedule_data.timepoint, uint256) + 7 * 24 * 60 * 60 <= block.timestamp:
        raw_revert(concat(method_id("AccessManagerExpired(bytes32)"), operation_id))
    self.schedules[operation_id].timepoint = 0
    log OperationExecuted(operationId=operation_id, nonce=schedule_data.nonce)
    return schedule_data.nonce


@internal
def _track_role(role_id: uint64):
    if role_id == ADMIN_ROLE or role_id == PUBLIC_ROLE or self.role_index[role_id] != 0:
        return
    count: uint256 = self.roles_count
    self.roles[count] = role_id
    self.roles_count = count + 1
    self.role_index[role_id] = count + 1


@internal
def _track_admin_role(admin: uint64):
    if admin == ADMIN_ROLE or self.admin_role_index[admin] != 0:
        return
    count: uint256 = self.admin_roles_count
    self.admin_roles[count] = admin
    self.admin_roles_count = count + 1
    self.admin_role_index[admin] = count + 1


@internal
def _remove_managed_role(admin: uint64, role_id: uint64):
    position: uint256 = self.admin_managed_index[admin][role_id]
    if position == 0:
        return
    index: uint256 = position - 1
    last_index: uint256 = self.admin_managed_roles_count[admin] - 1
    if index != last_index:
        moved: uint64 = self.admin_managed_roles[admin][last_index]
        self.admin_managed_roles[admin][index] = moved
        self.admin_managed_index[admin][moved] = position
    self.admin_managed_roles[admin][last_index] = 0
    self.admin_managed_roles_count[admin] = last_index
    self.admin_managed_index[admin][role_id] = 0


@internal
def _add_managed_role(admin: uint64, role_id: uint64):
    if admin == ADMIN_ROLE or self.admin_managed_index[admin][role_id] != 0:
        return
    self._track_admin_role(admin)
    count: uint256 = self.admin_managed_roles_count[admin]
    self.admin_managed_roles[admin][count] = role_id
    self.admin_managed_roles_count[admin] = count + 1
    self.admin_managed_index[admin][role_id] = count + 1


@internal
def _remove_member(role_id: uint64, account: address):
    position: uint256 = self.role_member_index[role_id][account]
    if position == 0:
        return
    index: uint256 = position - 1
    last_index: uint256 = self.role_members_count[role_id] - 1
    if index != last_index:
        moved: address = self.role_members[role_id][last_index]
        self.role_members[role_id][index] = moved
        self.role_member_index[role_id][moved] = position
    self.role_members[role_id][last_index] = empty(address)
    self.role_members_count[role_id] = last_index
    self.role_member_index[role_id][account] = 0


@internal
def _remove_target(role_id: uint64, target: address):
    position: uint256 = self.role_target_index[role_id][target]
    if position == 0:
        return
    index: uint256 = position - 1
    last_index: uint256 = self.role_targets_count[role_id] - 1
    if index != last_index:
        moved: address = self.role_targets[role_id][last_index]
        self.role_targets[role_id][index] = moved
        self.role_target_index[role_id][moved] = position
    self.role_targets[role_id][last_index] = empty(address)
    self.role_targets_count[role_id] = last_index
    self.role_target_index[role_id][target] = 0


@internal
def _remove_selector(role_id: uint64, target: address, selector: bytes4):
    position: uint256 = self.role_target_selector_index[role_id][target][selector]
    if position == 0:
        return
    index: uint256 = position - 1
    last_index: uint256 = self.role_target_selectors_count[role_id][target] - 1
    if index != last_index:
        moved: bytes4 = self.role_target_selectors[role_id][target][last_index]
        self.role_target_selectors[role_id][target][index] = moved
        self.role_target_selector_index[role_id][target][moved] = position
    self.role_target_selectors[role_id][target][last_index] = empty(bytes4)
    self.role_target_selectors_count[role_id][target] = last_index
    self.role_target_selector_index[role_id][target][selector] = 0
    if self.role_target_selectors_count[role_id][target] == 0:
        self._remove_target(role_id, target)


@internal
def _add_selector(role_id: uint64, target: address, selector: bytes4):
    if self.role_target_selector_index[role_id][target][selector] == 0:
        selector_count: uint256 = self.role_target_selectors_count[role_id][target]
        self.role_target_selectors[role_id][target][selector_count] = selector
        self.role_target_selectors_count[role_id][target] = selector_count + 1
        self.role_target_selector_index[role_id][target][selector] = selector_count + 1
    if self.role_target_index[role_id][target] == 0:
        target_count: uint256 = self.role_targets_count[role_id]
        self.role_targets[role_id][target_count] = target
        self.role_targets_count[role_id] = target_count + 1
        self.role_target_index[role_id][target] = target_count + 1


@internal
def _set_selector_role(target: address, selector: bytes4, role_id: uint64):
    old_role: uint64 = self.tracked_selector_role[target][selector]
    self.target_roles[target][selector] = role_id
    log TargetFunctionRoleUpdated(target=target, selector=selector, roleId=role_id)
    self._track_role(role_id)
    if old_role == role_id:
        return
    if old_role != ADMIN_ROLE:
        self._remove_selector(old_role, target, selector)
    if role_id != ADMIN_ROLE:
        self._add_selector(role_id, target, selector)
    self.tracked_selector_role[target][selector] = role_id


@internal
@view
def _slice_end(start: uint256, end: uint256, length: uint256) -> (uint256, uint256):
    bounded_end: uint256 = min(end, length)
    return min(start, bounded_end), bounded_end


@external
@view
def canCall(caller: address, target: address, selector: bytes4) -> (bool, uint32):
    if caller == self and self.execution_id == keccak256(concat(convert(target, bytes32), convert(selector, bytes32))):
        return True, 0
    if self.target_closed[target]:
        return False, 0
    role_id: uint64 = self.target_roles[target][selector]
    member: bool = False
    delay: uint32 = 0
    member, delay = self._has_role(role_id, caller)
    if not member:
        return False, 0
    return delay == 0, delay


@external
@pure
def expiration() -> uint32:
    return 7 * 24 * 60 * 60


@external
@pure
def minSetback() -> uint32:
    return 5 * 24 * 60 * 60


@external
@view
def isTargetClosed(target: address) -> bool:
    return self.target_closed[target]


@external
@view
def getTargetFunctionRole(target: address, selector: bytes4) -> uint64:
    return self.target_roles[target][selector]


@external
@view
def getTargetAdminDelay(target: address) -> uint32:
    return self.target_admin_delay[target]


@external
@view
def getRoleAdmin(roleId: uint64) -> uint64:
    return self.role_admin[roleId]


@external
@view
def getRoleGuardian(roleId: uint64) -> uint64:
    return self.role_guardian[roleId]


@external
@view
def getRoleGrantDelay(roleId: uint64) -> uint32:
    return self.role_grant_delay[roleId]


@external
@view
def getAccess(roleId: uint64, account: address) -> (uint48, uint32, uint32, uint48):
    access: Access = self.role_access[roleId][account]
    return access.since, access.delay, 0, 0


@external
@view
def hasRole(roleId: uint64, account: address) -> (bool, uint32):
    return self._has_role(roleId, account)


@external
def labelRole(roleId: uint64, label: String[MAX_LABEL]):
    self._require_admin()
    if roleId == ADMIN_ROLE or roleId == PUBLIC_ROLE:
        raw_revert(concat(method_id("AccessManagerLockedRole(uint64)"), convert(roleId, bytes32)))
    old_label: String[MAX_LABEL] = self.role_label[roleId]
    has_old: bool = len(old_label) != 0
    if len(label) == 0:
        if not has_old:
            raw_revert(concat(method_id("AccessManagerUnlabeledRole(uint64)"), convert(roleId, bytes32)))
        old_hash: bytes32 = keccak256(old_label)
        position: uint256 = self.label_index[old_hash]
        index: uint256 = position - 1
        last_index: uint256 = self.labels_count - 1
        if index != last_index:
            moved: String[MAX_LABEL] = self.labels[last_index]
            self.labels[index] = moved
            self.label_index[keccak256(moved)] = position
        self.labels[last_index] = ""
        self.labels_count = last_index
        self.label_index[old_hash] = 0
        self.label_role[old_hash] = 0
        self.role_label[roleId] = ""
        log RoleLabel(roleId=roleId, label=label)
        return
    if has_old:
        raw_revert(concat(method_id("AccessManagerRoleAlreadyLabeled(uint64)"), convert(roleId, bytes32)))
    label_hash: bytes32 = keccak256(label)
    if self.label_index[label_hash] != 0:
        raw_revert(
            concat(
                method_id("AccessManagerLabelAlreadyUsed(string,uint64)"),
                abi_encode(label, self.label_role[label_hash]),
            )
        )
    self._track_role(roleId)
    count: uint256 = self.labels_count
    self.labels[count] = label
    self.labels_count = count + 1
    self.label_index[label_hash] = count + 1
    self.label_role[label_hash] = roleId
    self.role_label[roleId] = label
    log RoleLabel(roleId=roleId, label=label)


@external
def grantRole(roleId: uint64, account: address, executionDelay: uint32):
    self._require_role(self.role_admin[roleId])
    if roleId == PUBLIC_ROLE:
        raw_revert(concat(method_id("AccessManagerLockedRole(uint64)"), convert(roleId, bytes32)))
    access: Access = self.role_access[roleId][account]
    new_member: bool = access.since == 0
    since: uint48 = access.since
    if new_member:
        since = convert(block.timestamp + convert(self.role_grant_delay[roleId], uint256), uint48)
        if since == 0:
            since = 1
        count: uint256 = self.role_members_count[roleId]
        self.role_members[roleId][count] = account
        self.role_members_count[roleId] = count + 1
        self.role_member_index[roleId][account] = count + 1
        self._track_role(roleId)
    self.role_access[roleId][account] = Access(since=since, delay=executionDelay)
    log RoleGranted(roleId=roleId, account=account, delay=executionDelay, since=since, newMember=new_member)


@external
def revokeRole(roleId: uint64, account: address):
    self._require_role(self.role_admin[roleId])
    if roleId == PUBLIC_ROLE:
        raw_revert(concat(method_id("AccessManagerLockedRole(uint64)"), convert(roleId, bytes32)))
    if self.role_access[roleId][account].since == 0:
        return
    self.role_access[roleId][account] = empty(Access)
    self._remove_member(roleId, account)
    log RoleRevoked(roleId=roleId, account=account)


@external
def renounceRole(roleId: uint64, callerConfirmation: address):
    if callerConfirmation != msg.sender:
        raw_revert(method_id("AccessManagerBadConfirmation()"))
    if roleId == PUBLIC_ROLE:
        raw_revert(concat(method_id("AccessManagerLockedRole(uint64)"), convert(roleId, bytes32)))
    if self.role_access[roleId][callerConfirmation].since == 0:
        return
    self.role_access[roleId][callerConfirmation] = empty(Access)
    self._remove_member(roleId, callerConfirmation)
    log RoleRevoked(roleId=roleId, account=callerConfirmation)


@external
def setRoleAdmin(roleId: uint64, admin: uint64):
    self._require_admin()
    if roleId == ADMIN_ROLE or roleId == PUBLIC_ROLE:
        raw_revert(concat(method_id("AccessManagerLockedRole(uint64)"), convert(roleId, bytes32)))
    old_admin: uint64 = self.role_admin[roleId]
    self.role_admin[roleId] = admin
    log RoleAdminChanged(roleId=roleId, admin=admin)
    self._track_role(roleId)
    if old_admin != admin:
        if old_admin != ADMIN_ROLE:
            self._remove_managed_role(old_admin, roleId)
        self._add_managed_role(admin, roleId)


@external
def setRoleGuardian(roleId: uint64, guardian: uint64):
    self._require_admin()
    if roleId == ADMIN_ROLE or roleId == PUBLIC_ROLE:
        raw_revert(concat(method_id("AccessManagerLockedRole(uint64)"), convert(roleId, bytes32)))
    self.role_guardian[roleId] = guardian
    self._track_role(roleId)
    log RoleGuardianChanged(roleId=roleId, guardian=guardian)


@external
def setGrantDelay(roleId: uint64, newDelay: uint32):
    self._require_admin()
    if roleId == PUBLIC_ROLE:
        raw_revert(concat(method_id("AccessManagerLockedRole(uint64)"), convert(roleId, bytes32)))
    self.role_grant_delay[roleId] = newDelay
    log RoleGrantDelayChanged(roleId=roleId, delay=newDelay, since=convert(block.timestamp, uint48))


@external
def setTargetFunctionRole(target: address, selectors: DynArray[bytes4, INF], roleId: uint64):
    self._require_admin()
    for selector: bytes4 in selectors:
        self._set_selector_role(target, selector, roleId)


@external
def setTargetAdminDelay(target: address, newDelay: uint32):
    self._require_admin()
    self.target_admin_delay[target] = newDelay
    log TargetAdminDelayUpdated(target=target, delay=newDelay, since=convert(block.timestamp, uint48))


@external
def setTargetClosed(target: address, closed: bool):
    self._require_admin()
    self.target_closed[target] = closed
    log TargetClosed(target=target, closed=closed)


@external
@view
def getSchedule(id: bytes32) -> uint48:
    scheduled: uint48 = self.schedules[id].timepoint
    if scheduled != 0 and convert(scheduled, uint256) + 7 * 24 * 60 * 60 <= block.timestamp:
        return 0
    return scheduled


@external
@view
def getNonce(id: bytes32) -> uint32:
    return self.schedules[id].nonce


@external
@view
def hashOperation(caller: address, target: address, data: Bytes[MAX_CALLDATA]) -> bytes32:
    return keccak256(abi_encode(caller, target, data))


@external
def schedule(target: address, data: Bytes[MAX_CALLDATA], when: uint48) -> (bytes32, uint32):
    if len(data) < 4:
        raw_revert(concat(method_id("AccessManagerUnauthorizedCall(address,address,bytes4)"), convert(msg.sender, bytes32), convert(target, bytes32), empty(bytes32)))
    immediate: bool = False
    setback: uint32 = 0
    immediate, setback = self._can_call_data(msg.sender, target, data)
    selector: bytes4 = convert(slice(data, 0, 4), bytes4)
    minimum_when: uint256 = block.timestamp + convert(setback, uint256)
    if setback == 0 or (when != 0 and convert(when, uint256) < minimum_when):
        raw_revert(concat(method_id("AccessManagerUnauthorizedCall(address,address,bytes4)"), convert(msg.sender, bytes32), convert(target, bytes32), convert(selector, bytes32)))
    scheduled_when: uint48 = convert(max(convert(when, uint256), minimum_when), uint48)
    operation_id: bytes32 = keccak256(abi_encode(msg.sender, target, data))
    previous: uint48 = self.schedules[operation_id].timepoint
    if previous != 0 and convert(previous, uint256) + 7 * 24 * 60 * 60 > block.timestamp:
        raw_revert(concat(method_id("AccessManagerAlreadyScheduled(bytes32)"), operation_id))
    nonce: uint32 = unsafe_add(self.schedules[operation_id].nonce, 1)
    self.schedules[operation_id] = Schedule(timepoint=scheduled_when, nonce=nonce)
    log OperationScheduled(
        operationId=operation_id,
        nonce=nonce,
        schedule=scheduled_when,
        caller=msg.sender,
        target=target,
        data=data,
    )
    return operation_id, nonce


@external
@payable
def execute(target: address, data: Bytes[MAX_CALLDATA]) -> uint32:
    if len(data) < 4:
        raw_revert(concat(method_id("AccessManagerUnauthorizedCall(address,address,bytes4)"), convert(msg.sender, bytes32), convert(target, bytes32), empty(bytes32)))
    selector: bytes4 = convert(slice(data, 0, 4), bytes4)
    immediate: bool = False
    delay: uint32 = 0
    immediate, delay = self._can_call_data(msg.sender, target, data)
    if not immediate and delay == 0:
        raw_revert(concat(method_id("AccessManagerUnauthorizedCall(address,address,bytes4)"), convert(msg.sender, bytes32), convert(target, bytes32), convert(selector, bytes32)))
    operation_id: bytes32 = keccak256(abi_encode(msg.sender, target, data))
    nonce: uint32 = 0
    scheduled: uint48 = self.schedules[operation_id].timepoint
    if delay != 0 or (scheduled != 0 and convert(scheduled, uint256) + 7 * 24 * 60 * 60 > block.timestamp):
        nonce = self._consume_schedule(operation_id)
    execution_id_before: bytes32 = self.execution_id
    self.execution_id = keccak256(concat(convert(target, bytes32), convert(selector, bytes32)))
    _result: Bytes[MAX_RETURN] = raw_call(target, data, value=msg.value, max_outsize=MAX_RETURN)
    self.execution_id = execution_id_before
    return nonce


@external
def cancel(caller: address, target: address, data: Bytes[MAX_CALLDATA]) -> uint32:
    selector: bytes4 = empty(bytes4)
    if len(data) >= 4:
        selector = convert(slice(data, 0, 4), bytes4)
    operation_id: bytes32 = keccak256(abi_encode(caller, target, data))
    if self.schedules[operation_id].timepoint == 0:
        raw_revert(concat(method_id("AccessManagerNotScheduled(bytes32)"), operation_id))
    if caller != msg.sender:
        is_admin: bool = False
        _admin_delay: uint32 = 0
        is_admin, _admin_delay = self._has_role(ADMIN_ROLE, msg.sender)
        guardian_role: uint64 = self.role_guardian[self.target_roles[target][selector]]
        is_guardian: bool = False
        _guardian_delay: uint32 = 0
        is_guardian, _guardian_delay = self._has_role(guardian_role, msg.sender)
        if not is_admin and not is_guardian:
            raw_revert(
                concat(
                    method_id("AccessManagerUnauthorizedCancel(address,address,address,bytes4)"),
                    convert(msg.sender, bytes32),
                    convert(caller, bytes32),
                    convert(target, bytes32),
                    convert(selector, bytes32),
                )
            )
    self.schedules[operation_id].timepoint = 0
    nonce: uint32 = self.schedules[operation_id].nonce
    log OperationCanceled(operationId=operation_id, nonce=nonce)
    return nonce


@external
def consumeScheduledOp(caller: address, data: Bytes[MAX_CALLDATA]):
    consuming_selector: bytes4 = staticcall IAccessManaged(msg.sender).isConsumingScheduledOp()
    if consuming_selector != convert(method_id("isConsumingScheduledOp()"), bytes4):
        raw_revert(concat(method_id("AccessManagerUnauthorizedConsume(address)"), convert(msg.sender, bytes32)))
    self._consume_schedule(keccak256(abi_encode(caller, msg.sender, data)))


@external
def updateAuthority(target: address, newAuthority: address):
    self._require_admin()
    raw_call(target, concat(method_id("setAuthority(address)"), convert(newAuthority, bytes32)), max_outsize=0)


@external
def multicall(data: DynArray[Bytes[MAX_CALLDATA], 64]) -> DynArray[Bytes[MAX_RETURN], 64]:
    results: DynArray[Bytes[MAX_RETURN], 64] = []
    for call_data: Bytes[MAX_CALLDATA] in data:
        result: Bytes[MAX_RETURN] = raw_call(self, call_data, max_outsize=MAX_RETURN, is_delegate_call=True)
        results.append(result)
    return results


@external
@view
def getRole(index: uint256) -> uint64:
    return self.roles[index]


@external
@view
def getRoleCount() -> uint256:
    return self.roles_count


@external
@view
def getRoles(start: uint256, end: uint256) -> DynArray[uint64, INF]:
    lower: uint256 = 0
    upper: uint256 = 0
    lower, upper = self._slice_end(start, end, self.roles_count)
    result: DynArray[uint64, INF] = []
    for i: uint256 in range(lower, upper, bound=115792089237316195423570985008687907853269984665640564039457584007913129639935):
        result.append(self.roles[i])
    return result


@external
@view
def isRole(roleId: uint64) -> bool:
    return self.role_index[roleId] != 0


@external
@view
def getAdminRole(index: uint256) -> uint64:
    return self.admin_roles[index]


@external
@view
def getAdminRoleCount() -> uint256:
    return self.admin_roles_count


@external
@view
def getAdminRoles(start: uint256, end: uint256) -> DynArray[uint64, INF]:
    lower: uint256 = 0
    upper: uint256 = 0
    lower, upper = self._slice_end(start, end, self.admin_roles_count)
    result: DynArray[uint64, INF] = []
    for i: uint256 in range(lower, upper, bound=115792089237316195423570985008687907853269984665640564039457584007913129639935):
        result.append(self.admin_roles[i])
    return result


@external
@view
def isAdminRole(adminRoleId: uint64) -> bool:
    return self.admin_role_index[adminRoleId] != 0


@external
@view
def getRoleMember(roleId: uint64, index: uint256) -> address:
    return self.role_members[roleId][index]


@external
@view
def getRoleMemberCount(roleId: uint64) -> uint256:
    return self.role_members_count[roleId]


@external
@view
def getRoleMembers(roleId: uint64, start: uint256, end: uint256) -> DynArray[address, INF]:
    lower: uint256 = 0
    upper: uint256 = 0
    lower, upper = self._slice_end(start, end, self.role_members_count[roleId])
    result: DynArray[address, INF] = []
    for i: uint256 in range(lower, upper, bound=115792089237316195423570985008687907853269984665640564039457584007913129639935):
        result.append(self.role_members[roleId][i])
    return result


@external
@view
def getRoleOfAdminRole(adminRoleId: uint64, index: uint256) -> uint64:
    return self.admin_managed_roles[adminRoleId][index]


@external
@view
def getRoleOfAdminRoleCount(adminRoleId: uint64) -> uint256:
    return self.admin_managed_roles_count[adminRoleId]


@external
@view
def getRolesOfAdminRole(adminRoleId: uint64, start: uint256, end: uint256) -> DynArray[uint64, INF]:
    lower: uint256 = 0
    upper: uint256 = 0
    lower, upper = self._slice_end(start, end, self.admin_managed_roles_count[adminRoleId])
    result: DynArray[uint64, INF] = []
    for i: uint256 in range(lower, upper, bound=115792089237316195423570985008687907853269984665640564039457584007913129639935):
        result.append(self.admin_managed_roles[adminRoleId][i])
    return result


@external
@view
def getRoleTarget(roleId: uint64, index: uint256) -> address:
    return self.role_targets[roleId][index]


@external
@view
def getRoleTargetCount(roleId: uint64) -> uint256:
    return self.role_targets_count[roleId]


@external
@view
def getRoleTargets(roleId: uint64, start: uint256, end: uint256) -> DynArray[address, INF]:
    lower: uint256 = 0
    upper: uint256 = 0
    lower, upper = self._slice_end(start, end, self.role_targets_count[roleId])
    result: DynArray[address, INF] = []
    for i: uint256 in range(lower, upper, bound=115792089237316195423570985008687907853269984665640564039457584007913129639935):
        result.append(self.role_targets[roleId][i])
    return result


@external
@view
def getRoleTargetSelector(roleId: uint64, target: address, index: uint256) -> bytes4:
    return self.role_target_selectors[roleId][target][index]


@external
@view
def getRoleTargetSelectorCount(roleId: uint64, target: address) -> uint256:
    return self.role_target_selectors_count[roleId][target]


@external
@view
def getRoleTargetSelectors(roleId: uint64, target: address, start: uint256, end: uint256) -> DynArray[bytes4, INF]:
    lower: uint256 = 0
    upper: uint256 = 0
    lower, upper = self._slice_end(start, end, self.role_target_selectors_count[roleId][target])
    result: DynArray[bytes4, INF] = []
    for i: uint256 in range(lower, upper, bound=115792089237316195423570985008687907853269984665640564039457584007913129639935):
        result.append(self.role_target_selectors[roleId][target][i])
    return result


@external
@view
def getRoleOfTargetSelector(target: address, selector: bytes4) -> uint64:
    return self.tracked_selector_role[target][selector]


@external
@view
def getRoleLabel(index: uint256) -> String[MAX_LABEL]:
    return self.labels[index]


@external
@view
def getRoleLabelCount() -> uint256:
    return self.labels_count


@external
@view
@raw_return
def getRoleLabels(start: uint256, end: uint256) -> Bytes[INF]:
    lower: uint256 = 0
    upper: uint256 = 0
    lower, upper = self._slice_end(start, end, self.labels_count)
    count: uint256 = upper - lower
    heads: Bytes[INF] = b""
    tails: Bytes[INF] = b""
    output_offset: uint256 = 32 * count
    for i: uint256 in range(lower, upper, bound=115792089237316195423570985008687907853269984665640564039457584007913129639935):
        label: String[MAX_LABEL] = self.labels[i]
        encoded_label: Bytes[INF] = abi_encode(label, ensure_tuple=False)
        heads = concat(heads, convert(output_offset, bytes32))
        tails = concat(tails, encoded_label)
        output_offset += len(encoded_label)
    return concat(convert(32, bytes32), convert(count, bytes32), heads, tails)


@external
@view
def isLabelAssigned(label: String[MAX_LABEL]) -> bool:
    return self.label_index[keccak256(label)] != 0


@external
@view
def isRoleLabeled(roleId: uint64) -> bool:
    return len(self.role_label[roleId]) != 0


@external
@view
def getLabelOfRole(roleId: uint64) -> String[MAX_LABEL]:
    label: String[MAX_LABEL] = self.role_label[roleId]
    if len(label) == 0:
        raw_revert(concat(method_id("AccessManagerUnlabeledRole(uint64)"), convert(roleId, bytes32)))
    return label


@external
@view
def getRoleOfLabel(label: String[MAX_LABEL]) -> uint64:
    label_hash: bytes32 = keccak256(label)
    if self.label_index[label_hash] == 0:
        raw_revert(concat(method_id("AccessManagerUnregisteredLabel(string)"), abi_encode(label)))
    return self.label_role[label_hash]
