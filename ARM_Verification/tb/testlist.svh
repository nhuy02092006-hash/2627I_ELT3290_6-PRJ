// ============================================================================
// testlist.svh - DANH SACH TEST (duoc `include trong driver.sv)
//
// Moi dong la mot test. Duong dan tinh tu thu muc goc ARM_Verification/ (noi
// ModelSim dang chay). File .dat: moi dong 1 lenh 32-bit hex (co the chen
// comment kieu // ...). Chuong trinh nen KET THUC bang lenh  EAFFFFFE  (B .)
// hoac de trong - cac o imem chua dung duoc driver tu dien san EAFFFFFE.
// Luu y: lenh dau tien (dia chi 0) nen la lenh idempotent, vi du
//        SUB R0, R15, R15 (E04F000F) nhu chuong trinh trong sach.
//
// Cu phap:
//   `RUN_TEST      ("tests/xxx/prog.dat",                    "TEN_TEST", 0)
//   `RUN_TEST_D    ("tests/xxx/prog.dat", "tests/xxx/data.dat", "TEN", 0)
//   `RUN_TEST_RST  ("tests/xxx/prog.dat",                    "TEN", 4)   // reset sau 4 chu ky
//   `EXPECT_MEM(100, 7)       // dat TRUOC lenh RUN_*: dmem[byte addr 100] phai = 7
//   tham so cuoi cua RUN_TEST / RUN_TEST_D: 1 = test tich hop, 0 = test don le
// ============================================================================

// ---- Smoke test: chuong trinh mau trong sach, khong can file ngoai ----
`RUN_BOOK_PROGRAM("T00_BOOK_FIG7_60")

// ---- Them test cua nhom o day (bo comment va sua duong dan) ----
`RUN_TEST   ("tests/test_add_sub/add_basic.dat",        "T01_ADD_BASIC", 0)
`RUN_TEST   ("tests/test_add_sub/sub_basic.dat",        "T02_SUB_BASIC", 0)
`RUN_TEST_D ("tests/test_add_sub/addsub_edge.dat", "tests/test_add_sub/edge_data.dat", "T03_ADDSUB_EDGE", 0)
`RUN_TEST_D ("tests/test_logic/and_test.dat", "tests/test_logic/logic_data.dat", "T04_AND", 0)
`RUN_TEST_D ("tests/test_logic/orr_test.dat", "tests/test_logic/logic_data.dat", "T05_ORR", 0)
`RUN_TEST_D ("tests/test_memory/ldr_test.dat", "tests/test_memory/ldr_data.dat", "T06_LDR", 0)
`RUN_TEST   ("tests/test_memory/str_test.dat",           "T07_STR", 0)
`RUN_TEST   ("tests/test_branch/beq_taken.dat",         "T08_BEQ_TAKEN", 0)
`RUN_TEST   ("tests/test_branch/beq_not_taken.dat",     "T09_BEQ_NOT_TAKEN", 0)
`EXPECT_MEM(36, 1)
`RUN_TEST   ("tests/test_integration/integ_all7.dat",   "T10_INTEGRATION", 1)
`RUN_TEST_RST("tests/test_integration/reset_midrun.dat", "T11_RESET_MIDRUN", 4)
