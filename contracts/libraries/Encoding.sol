// SPDX-License-Identifier: Unlicensed

pragma solidity >=0.8.4;
pragma experimental ABIEncoderV2;

import "./Directives.sol";

import "hardhat/console.sol";

/* @title Order encoding library */
library OrderEncoding {

    function decodeOrder (bytes calldata input) internal view returns
        (Directives.OrderDirective memory dir) {
        uint32 offset = 0;
        uint8 cnt;

        (dir.open_.token_, offset) = eatToken(input, offset);
        (dir.open_.limitQty_, offset) = eatInt128(input, offset);
        (dir.open_.dustThresh_, offset) = eatUInt128(input, offset);
        (dir.open_.useSurplus_, offset) = eatBool(input, offset);

        (cnt, offset) = eatUInt8(input, offset);
        dir.hops_ = new Directives.HopDirective[](cnt);
        for (uint i = 0; i < cnt; ++i) {
            offset = parseHop(dir.hops_[i], input, offset);
        }
    }
    
    function parseHop (Directives.HopDirective memory hop,
                       bytes calldata input, uint32 offset)
        private view returns (uint32 next) {
        uint8 poolCnt;
        (poolCnt, next) = eatUInt8(input, offset);

        hop.pools_ = new Directives.PoolDirective[](poolCnt);
        for (uint i = 0; i < poolCnt; ++i) {
            next = parsePool(hop.pools_[i], input, next);
        }

        (hop.settle_.token_, next) = eatToken(input, next);
        (hop.settle_.limitQty_, next) = eatInt128(input, next);
        (hop.settle_.dustThresh_, next) = eatUInt128(input, next);
        (hop.settle_.useSurplus_, next) = eatBool(input, next);

        (hop.improve_.isEnabled_, hop.improve_.useBaseSide_, next) =
            eatBool2(input, next);
    }

    function parsePool (Directives.PoolDirective memory pair,
                        bytes calldata input, uint32 offset)
        private view returns (uint32 next) {
        uint concCnt;

        (pair.poolIdx_, next) = eatUInt24(input, offset);

        (pair.ambient_.isAdd_, next) = eatBool(input, next);
        (pair.ambient_.liquidity_, next) = eatUInt128(input, next);

        (concCnt, next) = eatUInt8(input, next);
        pair.conc_ = new Directives.ConcentratedDirective[](concCnt);
        for (uint8 i = 0; i < concCnt; ++i) {
            
            next = parseConcentrated(pair.conc_[i], input, next);
        }

        (pair.swap_.liqMask_, next) = eatUInt8(input, next);
        (pair.swap_.isBuy_, pair.swap_.inBaseQty_, next) = eatBool2(input, next);
        (pair.swap_.qty_, next) = eatUInt128(input, next);
        (pair.swap_.limitPrice_, next) = eatUInt128(input, next);

        (pair.chain_.rollExit_, pair.chain_.swapDefer_,
         pair.chain_.offsetSurplus_, next) = eatBool3(input, next);
    }

    function parseConcentrated (Directives.ConcentratedDirective memory pass,
                                bytes calldata input, uint32 offset)
        private view returns (uint32 next) {

        uint8 bookendCnt;
        
        (pass.openTick_, next) = eatInt24(input, offset);
        (bookendCnt, next) = eatUInt8(input, next);

        pass.bookends_ = new Directives.ConcenBookend[](bookendCnt);
        for (uint8 i = 0; i < bookendCnt; ++i) {
            (pass.bookends_[i].closeTick_, next) = eatInt24(input, next);
            (pass.bookends_[i].isAdd_, next) = eatBool(input, next);
            (pass.bookends_[i].liquidity_, next) = eatUInt128(input, next);
        }
    }
    
    function eatBool (bytes calldata input, uint32 offset)
        internal view returns (bool on, uint32 next) {
        uint8 flag;
        (flag, next) = eatUInt8(input, offset);
        on = (flag > 0);
    }

    function eatBool2 (bytes calldata input, uint32 offset)
        internal view returns (bool onA, bool onB, uint32 next) {
        uint8 flag;
        (flag, next) = eatUInt8(input, offset);
        onA = ((flag & 0x2) > 0);
        onB = ((flag & 0x1) > 0);        
    }
    
    function eatBool3 (bytes calldata input, uint32 offset)
        internal view returns (bool onA, bool onB, bool onC, uint32 next) {
        uint8 flag;
        (flag, next) = eatUInt8(input, offset);
        onA = ((flag & 0x4) > 0);
        onB = ((flag & 0x2) > 0);
        onC = ((flag & 0x1) > 0);        
    }

    function eatBool4 (bytes calldata input, uint32 offset)
        internal view returns (bool onA, bool onB, bool onC, bool onD, uint32 next) {
        uint8 flag;
        (flag, next) = eatUInt8(input, offset);
        onA = ((flag & 0x8) > 0);
        onB = ((flag & 0x4) > 0);        
        onC = ((flag & 0x2) > 0);        
        onD = ((flag & 0x1) > 0);        
    }

    function eatBool5 (bytes calldata input, uint32 offset)
        internal view returns (bool onA, bool onB, bool onC, bool onD, bool onE,
                               uint32 next) {
        uint8 flag;
        (flag, next) = eatUInt8(input, offset);
        onA = ((flag & 0x10) > 0);
        onB = ((flag & 0x8) > 0);        
        onC = ((flag & 0x4) > 0);        
        onD = ((flag & 0x2) > 0);
        onE = ((flag & 0x1) > 0);
    }
    
    
    function eatUInt8 (bytes calldata input, uint32 offset)
        internal view returns (uint8 cnt, uint32 next) {
        cnt = uint8(input[offset]);
        next = offset + 1;
    }

    function eatUInt24 (bytes calldata input, uint32 offset)
        internal view returns (uint24 val, uint32 next) {
        bytes3 coded = input[offset] |
            (bytes3(input[offset+1]) >> 8) |
            (bytes3(input[offset+2]) >> 16);
        val = uint24(coded);
        next = offset + 3;
    }

    function eatToken (bytes calldata input, uint32 offset)
        internal view returns (address token, uint32 next) {
        token = abi.decode(input[offset:(offset+32)], (address));
        next = offset + 32;
    }

    function eatUInt256 (bytes calldata input, uint32 offset)
        internal view returns (uint256 delta, uint32 next) {
        delta = abi.decode(input[offset:(offset+32)], (uint256));
        next = offset + 32;
    }

    function eatUInt128 (bytes calldata input, uint32 offset)
        internal view returns (uint128 delta, uint32 next) {
        delta = abi.decode(input[offset:(offset+32)], (uint128));
        next = offset + 32;
    }

    function eatInt256 (bytes calldata input, uint32 offset)
        internal view returns (int256 delta, uint32 next) {
        uint8 isNegFlag;
        uint256 magn;
        (isNegFlag, next) = eatUInt8(input, offset);        
        (magn, next) = eatUInt256(input, next);
        delta = isNegFlag > 0 ? -int256(magn) : int256(magn);
    }

    function eatInt128 (bytes calldata input, uint32 offset)
        internal view returns (int128 delta, uint32 next) {
        uint8 isNegFlag;
        uint128 magn;
        (isNegFlag, next) = eatUInt8(input, offset);
        (magn, next) = eatUInt128(input, next);
        delta = isNegFlag > 0 ? -int128(magn) : int128(magn);
    }

    function eatInt24 (bytes calldata input, uint32 offset)
        internal view returns (int24 delta, uint32 next) {
        uint8 isNegFlag;
        uint24 magn;
        (isNegFlag, next) = eatUInt8(input, offset);
        (magn, next) = eatUInt24(input, next);
        delta = isNegFlag > 0 ? -int24(magn) : int24(magn);
    }

}
