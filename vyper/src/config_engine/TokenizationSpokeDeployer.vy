# pragma version 0.5.0a3

# Vyper counterpart of TokenizationSpokeDeployer.  Creation code is supplied
# once at deployment so the contract can deploy the pinned Vyper
# TokenizationSpoke implementation and the repository's transparent proxy via
# the Safe Singleton Factory without embedding either large blob in runtime
# code.

MAX_IMPLEMENTATION_CODE: constant(uint256) = 12288
MAX_PROXY_CODE: constant(uint256) = 6144
MAX_INIT_DATA: constant(uint256) = 1024
MAX_FACTORY_CALL: constant(uint256) = 20480
MAX_STRING: constant(uint256) = 128

CREATE2_FACTORY: constant(address) = 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7

implementation_creation_code: Bytes[MAX_IMPLEMENTATION_CODE]
proxy_creation_code: Bytes[MAX_PROXY_CODE]


@deploy
def __init__(implementationCreationCode: Bytes[MAX_IMPLEMENTATION_CODE], proxyCreationCode: Bytes[MAX_PROXY_CODE]):
    self.implementation_creation_code = implementationCreationCode
    self.proxy_creation_code = proxyCreationCode


@internal
@pure
def _address_from_hash(digest: bytes32) -> address:
    return convert(convert(digest, uint256) & (2**160 - 1), address)


@internal
@pure
def _implementation_salt(
    hub: address,
    underlying: address,
    name: String[MAX_STRING],
    symbol: String[MAX_STRING],
) -> bytes32:
    return keccak256(abi_encode(hub, underlying, name, symbol, "impl"))


@internal
@pure
def _proxy_salt(
    hub: address,
    underlying: address,
    name: String[MAX_STRING],
    symbol: String[MAX_STRING],
) -> bytes32:
    return keccak256(abi_encode(hub, underlying, name, symbol, "proxy"))


@internal
@pure
def _computed_address(salt: bytes32, creation_code: Bytes[MAX_FACTORY_CALL]) -> address:
    digest: bytes32 = keccak256(
        concat(
            0xff,
            convert(CREATE2_FACTORY, bytes20),
            salt,
            keccak256(creation_code),
        )
    )
    return self._address_from_hash(digest)


@internal
def _deploy(salt: bytes32, creation_code: Bytes[MAX_FACTORY_CALL]) -> address:
    expected: address = self._computed_address(salt, creation_code)
    result: Bytes[32] = raw_call(
        CREATE2_FACTORY,
        concat(salt, creation_code),
        max_outsize=32,
    )
    if len(result) < 20:
        raw_revert(method_id("Create2AddressDerivationFailure()"))
    deployed: address = convert(convert(slice(result, 0, 20), bytes20), address)
    if deployed != expected:
        raw_revert(method_id("Create2AddressDerivationFailure()"))
    return deployed


@internal
@view
def _implementation_init_code(hub: address, underlying: address) -> Bytes[MAX_FACTORY_CALL]:
    return concat(self.implementation_creation_code, abi_encode(hub, underlying))


@internal
@view
def _proxy_init_code(
    implementation: address,
    proxy_admin_owner: address,
    name: String[MAX_STRING],
    symbol: String[MAX_STRING],
) -> Bytes[MAX_FACTORY_CALL]:
    init_data: Bytes[MAX_INIT_DATA] = concat(
        method_id("initialize(string,string)"),
        abi_encode(name, symbol),
    )
    return concat(
        self.proxy_creation_code,
        abi_encode(implementation, proxy_admin_owner, init_data),
    )


@external
def deploy(
    hub: address,
    underlying: address,
    name: String[MAX_STRING],
    symbol: String[MAX_STRING],
    proxyAdminOwner: address,
) -> address:
    if proxyAdminOwner == empty(address):
        raw_revert(method_id("InvalidProxyAdminOwner()"))

    implementation: address = self._deploy(
        self._implementation_salt(hub, underlying, name, symbol),
        self._implementation_init_code(hub, underlying),
    )
    return self._deploy(
        self._proxy_salt(hub, underlying, name, symbol),
        self._proxy_init_code(implementation, proxyAdminOwner, name, symbol),
    )


@external
@view
def computeImplementationAddress(
    hub: address,
    underlying: address,
    name: String[MAX_STRING],
    symbol: String[MAX_STRING],
) -> address:
    return self._computed_address(
        self._implementation_salt(hub, underlying, name, symbol),
        self._implementation_init_code(hub, underlying),
    )


@external
@view
def computeProxyAddress(
    hub: address,
    underlying: address,
    name: String[MAX_STRING],
    symbol: String[MAX_STRING],
    proxyAdminOwner: address,
) -> address:
    implementation: address = self._computed_address(
        self._implementation_salt(hub, underlying, name, symbol),
        self._implementation_init_code(hub, underlying),
    )
    return self._computed_address(
        self._proxy_salt(hub, underlying, name, symbol),
        self._proxy_init_code(implementation, proxyAdminOwner, name, symbol),
    )
