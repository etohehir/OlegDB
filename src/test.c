//        DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
//                    Version 2, December 2004
//
// Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>
//
// Everyone is permitted to copy and distribute verbatim or modified
// copies of this license document, and changing it is allowed as long
// as the name is changed.
//
//            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
//   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
//
//  0. You just DO WHAT THE FUCK YOU WANT TO.
#include "test.h"

int test_open_close() {
    ol_database_obj db = ol_open(DB_PATH, OL_CONSUME_DIR);
    printf("Opened DB: %p.\n", db);
    ol_close(db);
    printf("Closed DB.\n");
    return 0;
}

int test_jar() {
    ol_database_obj db = ol_open(DB_PATH, OL_SLAUGHTER_DIR);
    printf("Opened DB: %p.\n", db);

    int i;
    unsigned char to_insert[] = "Wu-tang cat ain't nothin' to fuck with";
    for (i = 0; i < 100; i++) {
        char key[16] = "hashy";
        char append[5] = "";

        sprintf(append, "%i", i);
        strcat(key, append);

        int insert_result = ol_jar(db, key, to_insert, strlen((char*)to_insert));

        if (insert_result > 0 || db->rcrd_cnt != i+1) {
            printf("Error: Could not insert. Error code: %i\n", insert_result);
            ol_close(db);
            return 2;
        }
    }
    printf("Records inserted: %i.\n", db->rcrd_cnt);
    ol_close(db);
    return 0;
}

int test_unjar() {
    ol_database_obj db = ol_open(DB_PATH, OL_SLAUGHTER_DIR);
    printf("Opened DB: %p.\n", db);

    char key[] = "muh_hash_tho";
    unsigned char val[] = "{json: \"ain't real\"}";
    int inserted = ol_jar(db, key, val, strlen((char*)val));

    if (inserted > 0) {
        printf("Error: Could not insert. Error code: %i\n", inserted);
        ol_close(db);
        return 1;
    }

    ol_val item = ol_unjar(db, key);
    if (item == NULL) {
        printf("Error: Could not find key: %s\n", key);
        ol_close(db);
        return 2;
    }

    ol_close(db);
    return 0;
}

int test_scoop() {
    ol_database_obj db = ol_open(DB_PATH, OL_SLAUGHTER_DIR);
    printf("Opened DB: %p.\n", db);

    char key[] = "muh_hash_tho";
    unsigned char val[] = "{json: \"ain't real\"}";
    int inserted = ol_jar(db, key, val, strlen((char*)val));
    if (db->rcrd_cnt != 1 || inserted > 0) {
        printf("Record not inserted. Record count: %i\n", db->rcrd_cnt);
        return 2;
    }
    printf("Value inserted. Records: %i\n", db->rcrd_cnt);


    if (ol_scoop(db, "muh_hash_tho") == 0) {
        printf("Deleted record.\n");
    } else {
        printf("Could not delete record.\n");
        ol_close(db);
        return 1;
    }

    if (db->rcrd_cnt != 0) {
        printf("Record not deleted.\n");
        return 2;
    }

    printf("Record count is: %i\n", db->rcrd_cnt);
    ol_close(db);
    return 0;
}

int test_uptime() {
    ol_database_obj db = ol_open(DB_PATH, OL_CARESS_DIR);
    printf("Opened DB: %p.\n", db);

    sleep(3);
    int uptime = ol_uptime(db);
    printf("Uptime: %.i seconds\n", uptime);

    if (uptime < 3) {
        printf("Uptime incorrect.\n");
        ol_close(db);
        return 1;
    }

    ol_close(db);
    return 0;
}

int test_update() {
    return 1;
}

void run_tests(int results[2]) {
    int tests_run = 0;
    int tests_failed = 0;

    ol_test_start();
    ol_run_test(test_open_close);
    ol_run_test(test_jar);
    ol_run_test(test_unjar);
    ol_run_test(test_scoop);
    ol_run_test(test_uptime);
    ol_run_test(test_update);

    results[0] = tests_run;
    results[1] = tests_failed;
}