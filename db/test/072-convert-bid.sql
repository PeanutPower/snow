BEGIN;

SAVEPOINT before_tests;

-- Test: Convert bid
-------------------------------------------------------------------------------------

DO $$ <<fn>>
DECLARE
    ask_uid int;
    bid_uid int;
    ask_oid int;
    bid_oid int;
    mrid int;
    ma "match"%ROWTYPE;
    bid_actual_xrp bigint;
BEGIN
    INSERT INTO currency (currency_id, scale, fiat)
    VALUES ('BTC', 8, false), ('XRP', 6, false);

    INSERT INTO account (currency_id, type)
    VALUES ('BTC', 'edge'), ('XRP', 'edge'), ('BTC', 'fee'), ('XRP', 'fee');

    INSERT INTO market (base_currency_id, quote_currency_id, scale)
    VALUES ('BTC', 'XRP', 3)
    RETURNING market_id INTO mrid;

    ask_uid := create_user('a@a', repeat('a', 64));
    bid_uid := create_user('b@b', repeat('b', 64));

    PERFORM edge_credit(ask_uid, 'BTC', 10e8::bigint);
    PERFORM edge_credit(bid_uid, 'XRP', 5000e6::bigint);

    -- ASK 10 BTC @ 750 XRP (7500 XRP)
    INSERT INTO "order" (user_id, market_id, type, volume, price)
    VALUES (ask_uid, mrid, 'ask', 10e5, 750e3); -- = 7500 XRP
    ask_oid := currval('order_order_id_seq');

    RAISE NOTICE '-----------------------------------------------------------------------------------';

    PERFORM convert_bid(bid_uid, mrid, 5000e6::bigint);

    bid_actual_xrp := (SELECT balance FROM account WHERE user_id = bid_uid AND currency_id = 'XRP');

    IF bid_actual_xrp > 1e5::bigint THEN
        RAISE 'Expected bidders actual XRP % to equal %', bid_actual_xrp, 10e10::bigint;
    END IF;
END; $$; ROLLBACK TO before_tests;

ROLLBACK;
