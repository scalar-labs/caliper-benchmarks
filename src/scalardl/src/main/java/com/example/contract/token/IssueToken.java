package com.example.contract.token;

import com.scalar.dl.ledger.asset.Asset;
import com.scalar.dl.ledger.contract.Contract;
import com.scalar.dl.ledger.database.Ledger;
import com.scalar.dl.ledger.exception.ContractContextException;
import java.util.Optional;
import javax.json.Json;
import javax.json.JsonObject;
import javax.json.JsonObjectBuilder;

public class IssueToken extends Contract {

  @Override
  public JsonObject invoke(Ledger ledger, JsonObject argument, Optional<JsonObject> properties) {
    if (!argument.containsKey(Const.KEY_USER_ID) || !argument.containsKey(Const.KEY_AMOUNT)) {
      throw new ContractContextException(
          "Please set " + Const.KEY_USER_ID + " and " + Const.KEY_AMOUNT + " in the argument");
    }

    String userId = Integer.toString(argument.getInt(Const.KEY_USER_ID));
    int amount = argument.getInt(Const.KEY_AMOUNT);

    Optional<Asset> asset = ledger.get(userId);
    if (!asset.isPresent()) {
      throw new ContractContextException(Const.ERR_NOT_FOUND);
    }

    JsonObject data = asset.get().data();
    int tokenBalance = data.getInt(Const.KEY_TOKEN_BALANCE);
    tokenBalance += amount;

    JsonObjectBuilder newData = Json.createObjectBuilder(data);
    newData.add(Const.KEY_TOKEN_BALANCE, tokenBalance);
    ledger.put(userId, newData.build());

    return null;
  }
}
