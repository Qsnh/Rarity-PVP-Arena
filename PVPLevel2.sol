// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface rarity {
    function level(uint256) external view returns (uint256);

    function class(uint256) external view returns (uint256);

    function getApproved(uint256) external view returns (address);

    function ownerOf(uint256) external view returns (address);

    function summoner(uint256)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );
}

interface attributes {
    function character_created(uint256) external view returns (bool);

    function ability_scores(uint256)
        external
        view
        returns (
            uint32,
            uint32,
            uint32,
            uint32,
            uint32,
            uint32
        );
}

interface gold {
    function transfer(
        uint256,
        uint256,
        uint256
    ) external returns (bool);

    function balanceOf(uint256) external view returns (uint256);
}

contract PVPLevel2 {
    // rarity constant rm = rarity(0xce761D788DF608BD21bdd59d6f4B54b2e27F25Bb);
    // attributes constant _attr =
    //     attributes(0xB5F5AF1087A8DA62A23b08C00C6ec9af21F397a1);
    // gold constant gld = gold(0x2069B76Afe6b734Fb65D1d099E7ec64ee9CC76B2);

    rarity constant rm = rarity(0xd9145CCE52D386f254917e481eB44e9943F39138);
    attributes constant _attr =
        attributes(0xf8e81D47203A594245E36C48e151709F0C19fBe8);
    gold constant gld = gold(0xd8b934580fcE35a11B58C6D73aDeE468a2833fa8);

    uint256 constant REWARD = 50e18;
    uint256 constant LIMIT = 3600;
    uint256 constant LEVEL = 2;

    event PK(uint256 _summoner, uint256 _opSummoner, bool _isWin);

    struct ability_score {
        uint256 id;
        uint256 class;
        uint256 strength;
        uint256 dexterity;
        uint256 constitution;
        uint256 intelligence;
        uint256 wisdom;
        uint256 charisma;
    }

    mapping(uint256 => ability_score) summonerAbility;
    mapping(uint256 => uint256) summonerIndex;
    mapping(uint256 => uint256) adLog;

    uint256 public total;

    function play(uint256 _summoner)
        external
        returns (
            uint256,
            uint256,
            bool
        )
    {
        require(_isOwner(_summoner), "not owner");
        require(_isApproved(_summoner), "unapprove");
        require(summonerAbility[_summoner].id > 0, "not created");
        require(gld.balanceOf(_summoner) >= REWARD, "insufficient balance");
        require(block.timestamp >= adLog[_summoner], "lock");

        uint256 _randomNum = random(toString(block.timestamp)) % total;
        if (_randomNum == 0) {
            _randomNum = 1;
        }

        uint256 _opSummoner = summonerIndex[_randomNum];

        require(_opSummoner != _summoner, "self");

        require(_isApproved(_opSummoner), "op unapprove");
        require(
            gld.balanceOf(_opSummoner) >= REWARD,
            "op insufficient balance"
        );

        bool _isWin = scout(_summoner, _opSummoner);

        if (_isWin) {
            // _summoner win
            gld.transfer(_opSummoner, _summoner, REWARD);
        } else {
            gld.transfer(_summoner, _opSummoner, REWARD);
        }

        adLog[_summoner] = block.timestamp + LIMIT;

        emit PK(_summoner, _opSummoner, _isWin);

        return (_summoner, _opSummoner, _isWin);
    }

    function join(uint256 _summoner) external {
        require(_isOwner(_summoner), "not owner");
        require(_isApproved(_summoner), "unapprove");
        require(_summoner > 0, "ban 0 _summoner");
        require(summonerAbility[_summoner].id == 0, "created");

        (, , , uint256 _level) = rm.summoner(_summoner);
        require(_level == LEVEL, "level 2");

        require(gld.balanceOf(_summoner) >= REWARD, "insufficient balance");

        (
            uint32 _str,
            uint32 _dex,
            uint32 _const,
            uint32 _int,
            uint32 _wis,
            uint32 _chr
        ) = _attr.ability_scores(_summoner);

        summonerAbility[_summoner] = ability_score(
            _summoner,
            rm.class(_summoner),
            uint256(_str),
            uint256(_dex),
            uint256(_const),
            uint256(_int),
            uint256(_wis),
            uint256(_chr)
        );

        summonerIndex[total] = _summoner;
        total++;
    }

    function updateAlibity(uint256 _summoner) external {
        require(_isOwner(_summoner), "not owner");
        require(_isApproved(_summoner), "unapprove");
        require(summonerAbility[_summoner].id > 0, "not created");

        (, , , uint256 _level) = rm.summoner(_summoner);
        require(_level == LEVEL);

        (
            uint32 _str,
            uint32 _dex,
            uint32 _const,
            uint32 _int,
            uint32 _wis,
            uint32 _chr
        ) = _attr.ability_scores(_summoner);

        summonerAbility[_summoner].strength = uint256(_str);
        summonerAbility[_summoner].dexterity = uint256(_dex);
        summonerAbility[_summoner].constitution = uint256(_const);
        summonerAbility[_summoner].intelligence = uint256(_int);
        summonerAbility[_summoner].wisdom = uint256(_wis);
        summonerAbility[_summoner].charisma = uint256(_chr);
    }

    function scout(uint256 _s1, uint256 _s2) public view returns (bool _isWin) {
        // s1 prop
        uint256 _s1Class = rm.class(_s1);
        uint256 _s1Str = summonerAbility[_s1].strength;
        uint256 _s1Dex = summonerAbility[_s1].dexterity;
        uint256 _s1Const = summonerAbility[_s1].constitution;
        // s1Health
        int256 _s1Health = int256(
            health_by_class_and_level(_s1Class, LEVEL, _s1Const)
        );
        // s1 damage
        int256 _s1Damage = int256(damage(_s1Str));

        // s2 prop
        uint256 _s2Class = rm.class(_s2);
        uint256 _s2Str = summonerAbility[_s2].strength;
        uint256 _s2Dex = summonerAbility[_s2].dexterity;
        uint256 _s2Const = summonerAbility[_s2].constitution;
        // s2Health
        int256 _s2Health = int256(
            health_by_class_and_level(_s2Class, LEVEL, _s2Const)
        );
        // s2 damage
        int256 _s2Damage = int256(damage(_s2Str));

        if (_s1Dex >= _s2Dex) {
            for (uint256 i = 0; i < 20; i++) {
                _s2Health -= _s1Damage;
                if (_s2Health <= 0) {
                    _isWin = true;
                    break;
                }
                _s1Health -= _s2Damage;
                if (_s1Health <= 0) {
                    break;
                }
            }
        } else {
            for (uint256 i = 0; i < 20; i++) {
                _s1Health -= _s2Damage;
                if (_s1Health <= 0) {
                    break;
                }
                _s2Health -= _s1Damage;
                if (_s2Health <= 0) {
                    _isWin = true;
                    break;
                }
            }
        }
    }

    function health_by_class(uint256 _class)
        public
        pure
        returns (uint256 health)
    {
        if (_class == 1) {
            health = 12;
        } else if (_class == 2) {
            health = 6;
        } else if (_class == 3) {
            health = 8;
        } else if (_class == 4) {
            health = 8;
        } else if (_class == 5) {
            health = 10;
        } else if (_class == 6) {
            health = 8;
        } else if (_class == 7) {
            health = 10;
        } else if (_class == 8) {
            health = 8;
        } else if (_class == 9) {
            health = 6;
        } else if (_class == 10) {
            health = 4;
        } else if (_class == 11) {
            health = 4;
        }
    }

    function health_by_class_and_level(
        uint256 _class,
        uint256 _level,
        uint256 _const
    ) public pure returns (uint256 health) {
        int256 _mod = modifier_for_attribute(_const);
        int256 _base_health = int256(health_by_class(_class)) + _mod;
        if (_base_health <= 0) {
            _base_health = 1;
        }
        health = uint256(_base_health) * _level;
    }

    function modifier_for_attribute(uint256 _attribute)
        public
        pure
        returns (int256 _modifier)
    {
        if (_attribute == 9) {
            return -1;
        }
        return (int256(_attribute) - 10) / 2;
    }

    function damage(uint256 _str) public pure returns (uint256) {
        int256 _mod = modifier_for_attribute(_str);
        if (_mod <= 1) {
            return 1;
        } else {
            return uint256(_mod);
        }
    }

    function _isApproved(uint256 _summoner) internal view returns (bool) {
        return rm.getApproved(_summoner) == address(this);
    }

    function _isOwner(uint256 _summoner) internal view returns (bool) {
        return rm.ownerOf(_summoner) == msg.sender;
    }

    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
