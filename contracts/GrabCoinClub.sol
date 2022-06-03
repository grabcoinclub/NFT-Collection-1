// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GrabCoinClub is ERC721, ERC721Enumerable, ReentrancyGuard, Ownable {
    using Strings for uint256;

    uint256 public constant maxSupply = 15555;
    uint256 public mintLimit = 5; // TODO
    uint256 public mintPresaleLimit = 1; // TODO
    mapping(uint256 => uint256) public mintedAt;
    mapping(address => mapping(uint256 => uint256)) public mintsOf;
    mapping(address => mapping(uint256 => uint256)) public mintsPresaleOf;
    mapping(address => uint256) public mintNonce;

    // Series
    struct Series {
        uint256 id;
        bool unlocked;
        uint256 next;
        uint256 last;
    }
    uint256 public constant seriesTotal = 15;
    Series[seriesTotal] public series;

    // Metadata
    string public contractURI; // TODO
    string public baseURI; // TODO
    string public baseExtension = ".json";

    // Addresses
    address public admin = 0x833A386DbF31b5CA853b418716ADD0F5511A365b; // TODO
    address public signer = 0x0E52Bee0EF46ed96F2CA50Ea22B5C1B5C750a1d4; // TODO
    address public wallet = 0x92c8a2B4E36eCa320909387B6EdA9867a6Fc214E; // TODO

    constructor() ERC721("GrabCoinClub", "GCC") {
        uint256[seriesTotal] memory series_ = [
            uint256(3000),
            uint256(2800),
            uint256(2300),
            uint256(2000),
            uint256(1700),
            uint256(1500),
            uint256(1000),
            uint256(550),
            uint256(300),
            uint256(200),
            uint256(100),
            uint256(50),
            uint256(25),
            uint256(20),
            uint256(10)
        ];
        uint256 last = 0;
        for (uint256 i = 0; i < series_.length; i++) {
            series[i] = Series(i, i < 7, last, last += series_[i]);
        }
    }

    // Mint
    function mintAdmin(uint256 series_, uint256 quantity_) public onlyAdmin {
        _internalMint(series_, quantity_, _msgSender());
    }

    function mintAirdrop(uint256 series_, address[] memory accounts_)
        public
        onlyAdmin
    {
        for (uint256 i = 0; i < accounts_.length; i++) {
            _internalMint(series_, 1, accounts_[i]);
        }
    }

    function mintPresale(
        uint256 series_,
        uint256 quantity_,
        address tokenAddress_,
        uint256 amount_,
        uint256 nonce_,
        bytes memory signature_
    ) public payable {
        _checkSignature(
            _msgSender(),
            series_,
            quantity_,
            tokenAddress_,
            amount_,
            nonce_,
            signature_
        );
        _distribute(_msgSender(), tokenAddress_, amount_);
        _internalMintWithLimit(
            series_,
            quantity_,
            _msgSender(),
            mintPresaleLimit,
            mintsPresaleOf[_msgSender()][series_]
        );
        mintsPresaleOf[_msgSender()][series_] += quantity_;
    }

    function mint(
        uint256 series_,
        uint256 quantity_,
        address tokenAddress_,
        uint256 amount_,
        uint256 nonce_,
        bytes memory signature_
    ) public payable {
        _checkSignature(
            _msgSender(),
            series_,
            quantity_,
            tokenAddress_,
            amount_,
            nonce_,
            signature_
        );
        _distribute(_msgSender(), tokenAddress_, amount_);
        _internalMintWithLimit(
            series_,
            quantity_,
            _msgSender(),
            mintLimit,
            mintsOf[_msgSender()][series_]
        );
        mintsOf[_msgSender()][series_] += quantity_;
    }

    function _internalMintWithLimit(
        uint256 series_,
        uint256 quantity_,
        address account_,
        uint256 mintLimit_,
        uint256 mints_
    ) private {
        require(mints_ + quantity_ <= mintLimit_, "Mint limit");
        _internalMint(series_, quantity_, account_);
    }

    function _internalMint(
        uint256 series_,
        uint256 quantity_,
        address account_
    ) private nonReentrant {
        require(series[series_].unlocked, "Series locked");
        require(
            series[series_].next + quantity_ <= series[series_].last,
            "Out of bounds"
        );

        for (uint256 i = 0; i < quantity_; i++) {
            uint256 tokenId = series[series_].next++;
            _safeMint(account_, tokenId);
            mintedAt[tokenId] = block.timestamp;
        }
    }

    function _distribute(
        address from_,
        address tokenAddress_,
        uint256 amount_
    ) private {
        if (tokenAddress_ == address(0) && amount_ > 0) {
            _sendEth(wallet, amount_);
        } else if (amount_ > 0) {
            IERC20(tokenAddress_).transferFrom(from_, address(this), amount_);
            _sendErc20(tokenAddress_, wallet, amount_);
        }
    }

    function setMintLimit(uint256 newMintLimit) public onlyOwner {
        mintLimit = newMintLimit;
    }

    function setMintPresaleLimit(uint256 newMintPresaleLimit) public onlyOwner {
        mintPresaleLimit = newMintPresaleLimit;
    }

    // Overrides
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        return
            bytes(baseURI).length > 0
                ? string(
                    abi.encodePacked(baseURI, tokenId.toString(), baseExtension)
                )
                : "";
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // Extra
    function rawOwnerOf(uint256 tokenId) public view returns (address) {
        if (_exists(tokenId)) return ownerOf(tokenId);
        return address(0);
    }

    function tokensOfOwner(address owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 balance = balanceOf(owner);
        require(0 < balance, "ERC721Enumerable: owner index out of bounds");
        uint256[] memory tokenIds = new uint256[](balance);
        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
        return tokenIds;
    }

    // Metadata
    function setContractURI(string memory contractURI_) public onlyOwner {
        contractURI = contractURI_;
    }

    function setBaseURI(string memory baseURI_) public onlyOwner {
        baseURI = baseURI_;
    }

    function setBaseExtension(string memory baseExtension_) public onlyOwner {
        baseExtension = baseExtension_;
    }

    // Series
    function seriesOf(uint256 tokenId) public view returns (uint256 seriesId) {
        require(tokenId < maxSupply, "Out of bounds");
        for (uint256 i = 0; i < series.length; i++) {
            if (tokenId < series[i].last) {
                return i;
            }
        }
    }

    function unlock(uint256 series_) public onlyOwner {
        series[series_].unlocked = true;
    }

    // Admin
    modifier onlyAdmin() {
        require(admin == _msgSender(), "Caller is not the admin");
        _;
    }

    function setAdmin(address newAdmin) public onlyOwner {
        admin = newAdmin;
    }

    // Signature
    function setSigner(address newSigner) public onlyOwner {
        signer = newSigner;
    }

    function signatureWallet(
        address wallet_,
        uint256 series_,
        uint256 quantity_,
        address tokenAddress_,
        uint256 amount_,
        uint256 nonce_,
        bytes memory signature_
    ) public pure returns (address) {
        return
            ECDSA.recover(
                keccak256(
                    abi.encode(
                        wallet_,
                        series_,
                        quantity_,
                        tokenAddress_,
                        amount_,
                        nonce_
                    )
                ),
                signature_
            );
    }

    function _checkSignature(
        address wallet_,
        uint256 series_,
        uint256 quantity_,
        address tokenAddress_,
        uint256 amount_,
        uint256 nonce_,
        bytes memory signature_
    ) private {
        require(
            mintNonce[wallet_] < nonce_,
            "Can not repeat a prior transaction!"
        );
        require(
            signatureWallet(
                wallet_,
                series_,
                quantity_,
                tokenAddress_,
                amount_,
                nonce_,
                signature_
            ) == signer,
            "Not authorized to mint"
        );
        mintNonce[wallet_] = nonce_;
    }

    // withdraw
    function setWallet(address newWallet) public onlyOwner {
        wallet = newWallet;
    }

    function withdraw(address to, uint256 amount) public onlyOwner {
        _sendEth(to, amount);
    }

    function withdrawErc20(
        address token,
        address to,
        uint256 amount
    ) public onlyOwner {
        _sendErc20(token, to, amount);
    }

    function _sendEth(address recipient, uint256 amount) private {
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "ETH_TRANSFER_FAILED");
    }

    function _sendErc20(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) private {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = tokenAddress.call(
            abi.encodeWithSelector(0xa9059cbb, recipient, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "ERC20_TRANSFER_FAILED"
        );
    }
}
