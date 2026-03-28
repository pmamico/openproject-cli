#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "státuszok lekérdezése" {
    run ./op_enum_status
    assert_output --partial "in progress"
}

@test "státusz id lekérdezése" {
    run ./op_enum_status "in progress"
    assert_output "6"
}

