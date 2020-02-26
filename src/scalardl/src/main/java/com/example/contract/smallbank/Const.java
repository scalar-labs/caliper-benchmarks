package com.example.contract.smallbank;

public class Const {

  private Const() {}

  /* Key names for JSON objects stored in Scalar DL */
  public static final String KEY_CUSTOMER_ID = "customer_id";
  public static final String KEY_CUSTOMER_NAME = "customer_name";
  public static final String KEY_CHECKING_BALANCE = "checking_balance";
  public static final String KEY_SAVINGS_BALANCE = "savings_balance";

  /* Key names for argments from Hyperledger Caliper */
  public static final String KEY_AMOUNT = "amount";
  public static final String KEY_INIT_CHK_BALANCE = "initial_checking_balance";
  public static final String KEY_INIT_SV_BALANCE = "initial_savings_balance";
  public static final String KEY_SRC_CUSTOMER_ID = "source_customer_id";
  public static final String KEY_DST_CUSTOMER_ID = "dest_customer_id";
  public static final String KEY_QUERY_KEY = "query_key"; // For Scalar DL Adapter

  /* Error messages */
  public static final String ERR_EXISTS = "Specified account already exists";
  public static final String ERR_NOT_FOUND = "Could not find specified account";
}
