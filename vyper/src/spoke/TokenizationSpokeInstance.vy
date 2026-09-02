# pragma version 0.5.0b1


error ERC20InsufficientAllowance:
    arg0: address
    arg1: uint256
    arg2: uint256

error ERC20InsufficientBalance:
    arg0: address
    arg1: uint256
    arg2: uint256

error ERC20InvalidApprover:
    arg0: address

error ERC20InvalidReceiver:
    arg0: address

error ERC20InvalidSender:
    arg0: address

error ERC20InvalidSpender:
    arg0: address

error InvalidAccountNonce:
    arg0: address
    arg1: uint256

error InvalidInitialization:
    pass

error InvalidSignature:
    pass

struct SpokeConfig:
    addCap: uint40
    drawCap: uint40
    riskPremiumThreshold: uint24
    active: bool
    halted: bool

struct Action:
    actor: address
    amount: uint256
    receiver: address
    nonce: uint256
    deadline: uint256

interface IHub:
    def getAssetId(underlying: address) -> uint256: view
    def getAssetUnderlyingAndDecimals(assetId: uint256) -> (address, uint8): view
    def MAX_ALLOWED_SPOKE_CAP() -> uint40: view
    def previewAddByAssets(assetId: uint256, assets: uint256) -> uint256: view
    def previewAddByShares(assetId: uint256, shares: uint256) -> uint256: view
    def previewRemoveByAssets(assetId: uint256, assets: uint256) -> uint256: view
    def previewRemoveByShares(assetId: uint256, shares: uint256) -> uint256: view
    def getSpokeConfig(assetId: uint256, spoke: address) -> SpokeConfig: view
    def getAssetLiquidity(assetId: uint256) -> uint256: view
    def add(assetId: uint256, amount: uint256) -> uint256: nonpayable
    def remove(assetId: uint256, amount: uint256, to: address) -> uint256: nonpayable


event SetTokenizationSpokeImmutables:
    hub: indexed(address)
    assetId: indexed(uint256)

event Initialized:
    version: uint64

event Transfer:
    sender: indexed(address)
    receiver: indexed(address)
    value: uint256

event Approval:
    owner: indexed(address)
    spender: indexed(address)
    value: uint256

event Deposit:
    sender: indexed(address)
    owner: indexed(address)
    assets: uint256
    shares: uint256

event Withdraw:
    sender: indexed(address)
    receiver: indexed(address)
    owner: indexed(address)
    assets: uint256
    shares: uint256


SPOKE_REVISION: public(constant(uint64)) = 1
PERMIT_NONCE_NAMESPACE: public(constant(uint192)) = 0
PERMIT_TYPEHASH: public(constant(bytes32)) = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9
DEPOSIT_TYPEHASH: public(constant(bytes32)) = 0xdecc632fabbd6d9f578203db4396740eb2d81cf0fd7681b726d116e49cbc240c
MINT_TYPEHASH: public(constant(bytes32)) = 0x12737e595645af6fb99e7985f3dff6fb716ac1ec517c0d2b21313985dc207343
WITHDRAW_TYPEHASH: public(constant(bytes32)) = 0xe81b79af873473ec5cb79baa56499159fca87ff2e3333f24183127408a14acb5
REDEEM_TYPEHASH: public(constant(bytes32)) = 0x03929148275eed00e4c3ef9c0ee72e49ec6cb96c7a34941708e052f9a511334e
DOMAIN_TYPEHASH: constant(bytes32) = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
NAME_HASH: constant(bytes32) = keccak256("Tokenization Spoke")
VERSION_HASH: constant(bytes32) = keccak256("1")

HUB: immutable(address)
ASSET_ID: immutable(uint256)
ASSET: immutable(address)
DECIMALS: immutable(uint8)
ASSET_UNITS: immutable(uint256)
MAX_ALLOWED_SPOKE_CAP: public(immutable(uint40))

# Assigned to their ERC-7201 namespaces by the build storage layout.
nonces_by_owner: HashMap[address, HashMap[uint192, uint256]]
balances: HashMap[address, uint256]
allowances: HashMap[address, HashMap[address, uint256]]
total_supply: uint256
token_name: String[128]
token_symbol: String[128]
initialized_state: uint256


@deploy
def __init__(hub: address, underlying: address):
    HUB = hub
    asset_id: uint256 = staticcall IHub(hub).getAssetId(underlying)
    ASSET_ID = asset_id
    asset: address = empty(address)
    decimals: uint8 = 0
    asset, decimals = staticcall IHub(hub).getAssetUnderlyingAndDecimals(asset_id)
    ASSET = asset
    DECIMALS = decimals
    units: uint256 = 1
    for i: uint256 in range(256):
        if i >= convert(decimals, uint256):
            break
        units = unsafe_mul(units, 10)
    ASSET_UNITS = units
    MAX_ALLOWED_SPOKE_CAP = staticcall IHub(hub).MAX_ALLOWED_SPOKE_CAP()
    self.initialized_state = convert(max_value(uint64), uint256)
    log Initialized(version=max_value(uint64))


@internal
@pure
def _pack_nonce(key: uint192, nonce: uint64) -> uint256:
    return unsafe_mul(convert(key, uint256), 2**64) | convert(nonce, uint256)


@internal
def _use_nonce(owner: address, key: uint192) -> uint256:
    nonce: uint64 = convert(self.nonces_by_owner[owner][key] & (2**64 - 1), uint64)
    self.nonces_by_owner[owner][key] = convert(unsafe_add(nonce, 1), uint256)
    return self._pack_nonce(key, nonce)


@internal
def _use_checked_nonce(owner: address, key_nonce: uint256):
    key: uint192 = convert(key_nonce // 2**64, uint192)
    current: uint256 = self._use_nonce(owner, key)
    if current != key_nonce:
        raise InvalidAccountNonce(owner, current)


@internal
@view
def _domain_separator() -> bytes32:
    return keccak256(abi_encode(DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, chain.id, self))


@internal
def _recover(digest: bytes32, v: uint256, r: bytes32, s: bytes32) -> address:
    return ecrecover(digest, v, r, s)


@internal
def _verify_intent(signer: address, intent_hash: bytes32, nonce: uint256, deadline: uint256, signature: Bytes[INF]):
    if block.timestamp > deadline or len(signature) != 65:
        raise InvalidSignature()
    digest: bytes32 = keccak256(concat(b"\x19\x01", self._domain_separator(), intent_hash))
    r: bytes32 = convert(slice(signature, 0, 32), bytes32)
    s: bytes32 = convert(slice(signature, 32, 32), bytes32)
    v: uint256 = convert(slice(signature, 64, 1), uint256)
    recovered: address = self._recover(digest, v, r, s)
    if recovered == empty(address) or recovered != signer:
        raise InvalidSignature()
    self._use_checked_nonce(signer, nonce)


@internal
def _approve(owner: address, spender: address, amount: uint256):
    if owner == empty(address):
        raise ERC20InvalidApprover(owner)
    if spender == empty(address):
        raise ERC20InvalidSpender(spender)
    self.allowances[owner][spender] = amount
    log Approval(owner=owner, spender=spender, value=amount)


@internal
def _spend_allowance(owner: address, spender: address, amount: uint256):
    current: uint256 = self.allowances[owner][spender]
    if current != max_value(uint256):
        if current < amount:
            raise ERC20InsufficientAllowance(spender, current, amount)
        self.allowances[owner][spender] = current - amount


@internal
def _mint(receiver: address, amount: uint256):
    if receiver == empty(address):
        raise ERC20InvalidReceiver(receiver)
    self.total_supply += amount
    self.balances[receiver] += amount
    log Transfer(sender=empty(address), receiver=receiver, value=amount)


@internal
def _burn(owner: address, amount: uint256):
    if owner == empty(address):
        raise ERC20InvalidSender(owner)
    balance: uint256 = self.balances[owner]
    if balance < amount:
        raise ERC20InsufficientBalance(owner, balance, amount)
    self.balances[owner] = balance - amount
    self.total_supply -= amount
    log Transfer(sender=owner, receiver=empty(address), value=amount)


@internal
def _transfer(sender: address, receiver: address, amount: uint256):
    if sender == empty(address):
        raise ERC20InvalidSender(sender)
    if receiver == empty(address):
        raise ERC20InvalidReceiver(receiver)
    balance: uint256 = self.balances[sender]
    if balance < amount:
        raise ERC20InsufficientBalance(sender, balance, amount)
    self.balances[sender] = balance - amount
    self.balances[receiver] += amount
    log Transfer(sender=sender, receiver=receiver, value=amount)


@internal
def _safe_transfer_from(token: address, owner: address, receiver: address, amount: uint256):
    result: Bytes[32] = raw_call(
        token,
        concat(
            method_id("transferFrom(address,address,uint256)"),
            convert(owner, bytes32),
            convert(receiver, bytes32),
            convert(amount, bytes32),
        ),
        max_outsize=32,
    )
    assert len(result) == 0 or abi_decode(result, bool)


@internal
@view
def _preview_deposit(assets: uint256) -> uint256:
    return staticcall IHub(HUB).previewAddByAssets(ASSET_ID, assets)


@internal
@view
def _preview_mint(shares: uint256) -> uint256:
    return staticcall IHub(HUB).previewAddByShares(ASSET_ID, shares)


@internal
@view
def _preview_withdraw(assets: uint256) -> uint256:
    return staticcall IHub(HUB).previewRemoveByAssets(ASSET_ID, assets)


@internal
@view
def _preview_redeem(shares: uint256) -> uint256:
    return staticcall IHub(HUB).previewRemoveByShares(ASSET_ID, shares)


@internal
def _deposit(depositor: address, receiver: address, assets: uint256, shares: uint256):
    self._safe_transfer_from(ASSET, depositor, HUB, assets)
    added_shares: uint256 = extcall IHub(HUB).add(ASSET_ID, assets)
    self._mint(receiver, shares)
    log Deposit(sender=depositor, owner=receiver, assets=assets, shares=shares)


@internal
def _withdraw(caller: address, receiver: address, owner: address, assets: uint256, shares: uint256):
    if caller != owner:
        self._spend_allowance(owner, caller, shares)
    self._burn(owner, shares)
    removed_shares: uint256 = extcall IHub(HUB).remove(ASSET_ID, assets, receiver)
    log Withdraw(sender=caller, receiver=receiver, owner=owner, assets=assets, shares=shares)


@external
def initialize(shareName: String[128], shareSymbol: String[128]):
    initialized: uint64 = convert(self.initialized_state & (2**64 - 1), uint64)
    if (self.initialized_state & (1 << 64)) != 0 or initialized >= SPOKE_REVISION:
        raise InvalidInitialization()
    self.initialized_state = convert(SPOKE_REVISION, uint256)
    self.token_name = shareName
    self.token_symbol = shareSymbol
    log SetTokenizationSpokeImmutables(hub=HUB, assetId=ASSET_ID)
    log Initialized(version=SPOKE_REVISION)


@external
@view
def name() -> String[128]:
    return self.token_name


@external
@view
def symbol() -> String[128]:
    return self.token_symbol


@external
@view
def decimals() -> uint8:
    return DECIMALS


@external
@view
def totalSupply() -> uint256:
    return self.total_supply


@external
@view
def balanceOf(account: address) -> uint256:
    return self.balances[account]


@external
def transfer(receiver: address, amount: uint256) -> bool:
    self._transfer(msg.sender, receiver, amount)
    return True


@external
@view
def allowance(owner: address, spender: address) -> uint256:
    return self.allowances[owner][spender]


@external
def approve(spender: address, amount: uint256) -> bool:
    self._approve(msg.sender, spender, amount)
    return True


@external
def transferFrom(sender: address, receiver: address, amount: uint256) -> bool:
    self._spend_allowance(sender, msg.sender, amount)
    self._transfer(sender, receiver, amount)
    return True


@external
@view
def hub() -> address:
    return HUB


@external
@view
def assetId() -> uint256:
    return ASSET_ID


@external
@view
def asset() -> address:
    return ASSET


@external
@view
def DOMAIN_SEPARATOR() -> bytes32:
    return self._domain_separator()


@external
@view
def eip712Domain() -> (bytes1, String[32], String[8], uint256, address, bytes32, DynArray[uint256, INF]):
    extensions: DynArray[uint256, INF] = []
    return 0x0f, "Tokenization Spoke", "1", chain.id, self, empty(bytes32), extensions


@external
@view
def nonces(owner: address, key: uint192 = 0) -> uint256:
    nonce: uint64 = convert(self.nonces_by_owner[owner][key] & (2**64 - 1), uint64)
    return self._pack_nonce(key, nonce)


@external
def useNonce(key: uint192) -> uint256:
    return self._use_nonce(msg.sender, key)


@external
def usePermitNonce() -> uint256:
    return self._use_nonce(msg.sender, PERMIT_NONCE_NAMESPACE)


@external
def permit(owner: address, spender: address, amount: uint256, deadline: uint256, v: uint8, r: bytes32, s: bytes32):
    if block.timestamp > deadline or owner == empty(address):
        raise InvalidSignature()
    nonce: uint256 = self._use_nonce(owner, PERMIT_NONCE_NAMESPACE)
    intent_hash: bytes32 = keccak256(abi_encode(PERMIT_TYPEHASH, owner, spender, amount, nonce, deadline))
    digest: bytes32 = keccak256(concat(b"\x19\x01", self._domain_separator(), intent_hash))
    recovered: address = self._recover(digest, convert(v, uint256), r, s)
    if recovered == empty(address) or recovered != owner:
        raise InvalidSignature()
    self._approve(owner, spender, amount)


@external
def renounceAllowance(owner: address):
    if self.allowances[owner][msg.sender] != 0:
        self._approve(owner, msg.sender, 0)


@external
@view
def previewDeposit(assets: uint256) -> uint256:
    return self._preview_deposit(assets)


@external
@view
def previewMint(shares: uint256) -> uint256:
    return self._preview_mint(shares)


@external
@view
def previewWithdraw(assets: uint256) -> uint256:
    return self._preview_withdraw(assets)


@external
@view
def previewRedeem(shares: uint256) -> uint256:
    return self._preview_redeem(shares)


@external
@view
def convertToShares(assets: uint256) -> uint256:
    return self._preview_deposit(assets)


@external
@view
def convertToAssets(shares: uint256) -> uint256:
    return self._preview_redeem(shares)


@external
@view
def totalAssets() -> uint256:
    return self._preview_redeem(self.total_supply)


@external
@view
def maxDeposit(_receiver: address) -> uint256:
    return self._max_deposit()


@internal
@view
def _max_deposit() -> uint256:
    config: SpokeConfig = staticcall IHub(HUB).getSpokeConfig(ASSET_ID, self)
    if not config.active or config.halted:
        return 0
    if config.addCap == MAX_ALLOWED_SPOKE_CAP:
        return max_value(uint256)
    allowed: uint256 = unsafe_mul(convert(config.addCap, uint256), ASSET_UNITS)
    balance: uint256 = self._preview_mint(self.total_supply)
    return allowed - min(allowed, balance)


@external
@view
def maxMint(receiver: address) -> uint256:
    max_assets: uint256 = self._max_deposit()
    if max_assets == max_value(uint256):
        return max_value(uint256)
    return self._preview_deposit(max_assets)


@internal
@view
def _max_removable_assets() -> uint256:
    config: SpokeConfig = staticcall IHub(HUB).getSpokeConfig(ASSET_ID, self)
    if not config.active or config.halted:
        return 0
    return staticcall IHub(HUB).getAssetLiquidity(ASSET_ID)


@external
@view
def maxWithdraw(owner: address) -> uint256:
    balance_assets: uint256 = self._preview_redeem(self.balances[owner])
    return min(balance_assets, self._max_removable_assets())


@external
@view
def maxRedeem(owner: address) -> uint256:
    removable_shares: uint256 = self._preview_deposit(self._max_removable_assets())
    return min(self.balances[owner], removable_shares)


@external
def deposit(assets: uint256, receiver: address) -> uint256:
    shares: uint256 = self._preview_deposit(assets)
    self._deposit(msg.sender, receiver, assets, shares)
    return shares


@external
def mint(shares: uint256, receiver: address) -> uint256:
    assets: uint256 = self._preview_mint(shares)
    self._deposit(msg.sender, receiver, assets, shares)
    return assets


@external
def withdraw(assets: uint256, receiver: address, owner: address) -> uint256:
    shares: uint256 = self._preview_withdraw(assets)
    self._withdraw(msg.sender, receiver, owner, assets, shares)
    return shares


@external
def redeem(shares: uint256, receiver: address, owner: address) -> uint256:
    assets: uint256 = self._preview_redeem(shares)
    self._withdraw(msg.sender, receiver, owner, assets, shares)
    return assets


@external
def depositWithSig(params: Action, signature: Bytes[INF]) -> uint256:
    intent_hash: bytes32 = keccak256(abi_encode(DEPOSIT_TYPEHASH, params.actor, params.amount, params.receiver, params.nonce, params.deadline))
    self._verify_intent(params.actor, intent_hash, params.nonce, params.deadline, signature)
    shares: uint256 = self._preview_deposit(params.amount)
    self._deposit(params.actor, params.receiver, params.amount, shares)
    return shares


@external
def mintWithSig(params: Action, signature: Bytes[INF]) -> uint256:
    intent_hash: bytes32 = keccak256(abi_encode(MINT_TYPEHASH, params.actor, params.amount, params.receiver, params.nonce, params.deadline))
    self._verify_intent(params.actor, intent_hash, params.nonce, params.deadline, signature)
    assets: uint256 = self._preview_mint(params.amount)
    self._deposit(params.actor, params.receiver, assets, params.amount)
    return assets


@external
def withdrawWithSig(params: Action, signature: Bytes[INF]) -> uint256:
    intent_hash: bytes32 = keccak256(abi_encode(WITHDRAW_TYPEHASH, params.actor, params.amount, params.receiver, params.nonce, params.deadline))
    self._verify_intent(params.actor, intent_hash, params.nonce, params.deadline, signature)
    shares: uint256 = self._preview_withdraw(params.amount)
    self._withdraw(params.actor, params.receiver, params.actor, params.amount, shares)
    return shares


@external
def redeemWithSig(params: Action, signature: Bytes[INF]) -> uint256:
    intent_hash: bytes32 = keccak256(abi_encode(REDEEM_TYPEHASH, params.actor, params.amount, params.receiver, params.nonce, params.deadline))
    self._verify_intent(params.actor, intent_hash, params.nonce, params.deadline, signature)
    assets: uint256 = self._preview_redeem(params.amount)
    self._withdraw(params.actor, params.receiver, params.actor, assets, params.amount)
    return assets


@external
def depositWithPermit(assets: uint256, receiver: address, deadline: uint256, v: uint8, r: bytes32, s: bytes32) -> uint256:
    success: bool = raw_call(
        ASSET,
        concat(
            method_id("permit(address,address,uint256,uint256,uint8,bytes32,bytes32)"),
            abi_encode(msg.sender, self, assets, deadline, v, r, s),
        ),
        revert_on_failure=False,
    )
    shares: uint256 = self._preview_deposit(assets)
    self._deposit(msg.sender, receiver, assets, shares)
    return shares
