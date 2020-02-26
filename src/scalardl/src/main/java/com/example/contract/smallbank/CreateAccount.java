package com.example.contract.smallbank;

import com.scalar.dl.ledger.asset.Asset;
import com.scalar.dl.ledger.contract.Contract;
import com.scalar.dl.ledger.database.Ledger;
import com.scalar.dl.ledger.exception.ContractContextException;
import java.util.Optional;
import javax.json.Json;
import javax.json.JsonObject;

public class CreateAccount extends Contract {

  @Override
  public JsonObject invoke(Ledger ledger, JsonObject argument, Optional<JsonObject> properties) {
    if (!argument.containsKey(Const.KEY_CUSTOMER_ID)
        || !argument.containsKey(Const.KEY_CUSTOMER_NAME)
        || !argument.containsKey(Const.KEY_INIT_CHK_BALANCE)
        || !argument.containsKey(Const.KEY_INIT_SV_BALANCE)) {
      throw new ContractContextException(
          "Please set "
              + Const.KEY_CUSTOMER_ID
              + ", "
              + Const.KEY_CUSTOMER_NAME
              + ", "
              + Const.KEY_INIT_CHK_BALANCE
              + " and "
              + Const.KEY_INIT_SV_BALANCE
              + " in the argument");
    }

    String customerId = Integer.toString(argument.getInt(Const.KEY_CUSTOMER_ID));
    String customerName = argument.getString(Const.KEY_CUSTOMER_NAME);
    int checkingBalance = argument.getInt(Const.KEY_INIT_CHK_BALANCE);
    int savingsBalance = argument.getInt(Const.KEY_INIT_SV_BALANCE);

    Optional<Asset> asset = ledger.get(customerId);
    if (asset.isPresent()) {
      throw new ContractContextException(Const.ERR_EXISTS);
    } else {
      ledger.put(
          customerId,
          Json.createObjectBuilder()
              .add(Const.KEY_CUSTOMER_NAME, customerName)
              .add(Const.KEY_CHECKING_BALANCE, checkingBalance)
              .add(Const.KEY_SAVINGS_BALANCE, savingsBalance)
              .build());
    }

    return null;
  }
}
