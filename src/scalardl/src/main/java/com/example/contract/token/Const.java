package com.example.contract.token;

public class Const {

  /* Key names for JSON objects stored in Scalar DL */
  public static final String KEY_USER_ID = "user_id";
  public static final String KEY_USER_NAME = "user_name";
  public static final String KEY_DOMAIN_ID = "domain_id";
  public static final String KEY_TOKEN_BALANCE = "token_balance";

  /* Key names for arguments from Hyperledger Caliper workload */
  public static final String KEY_AMOUNT = "amount";
  public static final String KEY_EXCHANGE_RATE = "exchange_rate";
  public static final String KEY_INIT_BALANCE = "initial_balance";
  public static final String KEY_SRC_USER_ID = "source_user_id";
  public static final String KEY_DST_USER_ID = "dest_user_id";

  /* Error messages */
  public static final String ERR_EXISTS = "Specified user already exists";
  public static final String ERR_NOT_FOUND = "Could not find specified user";
}
