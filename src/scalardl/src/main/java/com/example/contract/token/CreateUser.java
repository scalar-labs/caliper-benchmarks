package com.example.contract.token;

import com.scalar.dl.ledger.asset.Asset;
import com.scalar.dl.ledger.contract.Contract;
import com.scalar.dl.ledger.database.Ledger;
import com.scalar.dl.ledger.exception.ContractContextException;
import java.util.Optional;
import javax.json.Json;
import javax.json.JsonObject;

public class CreateUser extends Contract {

  @Override
  public JsonObject invoke(Ledger ledger, JsonObject argument, Optional<JsonObject> properties) {
    if (!argument.containsKey(Const.KEY_USER_ID)
        || !argument.containsKey(Const.KEY_USER_NAME)
        || !argument.containsKey(Const.KEY_DOMAIN_ID)
        || !argument.containsKey(Const.KEY_INIT_BALANCE)) {
      throw new ContractContextException(
          "Please set "
              + Const.KEY_USER_ID
              + ", "
              + Const.KEY_USER_NAME
              + ", "
              + Const.KEY_DOMAIN_ID
              + " and "
              + Const.KEY_INIT_BALANCE
              + " in the argument");
    }

    String userId = Integer.toString(argument.getInt(Const.KEY_USER_ID));
    String userName = argument.getString(Const.KEY_USER_NAME);
    String user_Type;
    int domainId = argument.getInt(Const.KEY_DOMAIN_ID);
    int tokenBalance = argument.getInt(Const.KEY_INIT_BALANCE);

    Optional<Asset> asset = ledger.get(userId);
    if (asset.isPresent()) {
      throw new ContractContextException(Const.ERR_EXISTS);
    } else {
      ledger.put(
          userId,
          Json.createObjectBuilder()
              .add(Const.KEY_USER_NAME, userName)
              .add(Const.KEY_DOMAIN_ID, domainId)
              .add(Const.KEY_TOKEN_BALANCE, tokenBalance)
              .build());
    }

    return null;
  }
}
