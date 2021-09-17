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
    rarity constant rm = rarity(0xce761D788DF608BD21bdd59d6f4B54b2e27F25Bb);
    attributes constant _attr =
        attributes(0xB5F5AF1087A8DA62A23b08C00C6ec9af21F397a1);
    gold constant gld = gold(0x2069B76Afe6b734Fb65D1d099E7ec64ee9CC76B2);

    uint256 constant BOSSID = 2451697;
    uint256 constant FEE = 10e18;
    uint256 constant REWARD = 50e18;
    uint256 constant LEVEL = 2;
    uint256 constant TOTAL = 100;

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

    uint256[100] tables;

    event PK(uint256 _s1, uint256 _s2, bool _isWin);

    function status() public view returns (uint256[100] memory _status) {
        for (uint256 i = 0; i < TOTAL; i++) {
            _status[i] = tables[i] > 0 ? 1 : 0;
        }
    }

    function challenge(uint256 _index, uint256 _opSummoner) external {
        require(_index >= 0 && _index < TOTAL, "_index error");
        uint256 _summoner = tables[_index];

        require(
            _summoner > 0 && _opSummoner > 0 && _opSummoner != _summoner,
            "summoner error"
        );

        require(_isOwner(_opSummoner), "no permission");
        require(_isApproved(_opSummoner), "unapprove");
        require(
            gld.balanceOf(_opSummoner) >= REWARD + FEE,
            "Insufficient balance"
        );

        uint256 _level = rm.level(_opSummoner);
        require(_level == LEVEL, "must level 2");
        (
            uint32 _str,
            uint32 _dex,
            uint32 _const,
            uint32 _int,
            uint32 _wis,
            uint32 _chr
        ) = _attr.ability_scores(_opSummoner);
        summonerAbility[_opSummoner] = ability_score(
            _opSummoner,
            rm.class(_opSummoner),
            uint256(_str),
            uint256(_dex),
            uint256(_const),
            uint256(_int),
            uint256(_wis),
            uint256(_chr)
        );

        if (
            _isApproved(_summoner) == false || gld.balanceOf(_summoner) < REWARD
        ) {
            tables[_index] = 0;
            // reward
            gld.transfer(BOSSID, _opSummoner, FEE);
            return;
        }

        gld.transfer(_opSummoner, BOSSID, FEE);

        bool _isWin = scout(_summoner, _opSummoner);
        if (_isWin) {
            // _summoner win
            gld.transfer(_opSummoner, _summoner, REWARD);
        } else {
            // _opSummoner is ringmaster
            tables[_index] = _opSummoner;
            gld.transfer(_summoner, _opSummoner, REWARD);
        }

        emit PK(_summoner, _opSummoner, _isWin);
    }

    function cancel(uint256 _index) external {
        require(_index >= 0 && _index < TOTAL, "_index error");
        uint256 _summoner = tables[_index];

        require(_isOwner(_summoner), "no permission");

        tables[_index] = 0;
    }

    function to_challenger(uint256 _index, uint256 _summoner) external {
        require(_summoner > 0, "ban summoner#0");
        require(_index >= 0 && _index < TOTAL, "_index error");
        require(tables[_index] == 0, "exists");

        require(_isOwner(_summoner), "no permission");
        require(_isApproved(_summoner), "unapprove");
        require(
            gld.balanceOf(_summoner) >= REWARD + FEE,
            "Insufficient balance"
        );

        gld.transfer(_summoner, BOSSID, FEE);

        tables[_index] = _summoner;

        uint256 _level = rm.level(_summoner);
        require(_level == LEVEL, "must level 2");

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
    }

    function updateAlibity(uint256 _summoner) external {
        require(_isOwner(_summoner), "not owner");
        require(_isApproved(_summoner), "unapprove");

        uint256 _level = rm.level(_summoner);
        require(_level == LEVEL, "must level 2");

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
    }

    function scout(uint256 _s1, uint256 _s2) public view returns (bool _isWin) {
        // s1 prop
        uint256 _s1Class = rm.class(_s1);
        uint256 _s1Str = summonerAbility[_s1].strength;
        int256 _s1Dex = modifier_for_attribute(summonerAbility[_s1].dexterity);
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
        int256 _s2Dex = modifier_for_attribute(summonerAbility[_s2].dexterity);
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
}
