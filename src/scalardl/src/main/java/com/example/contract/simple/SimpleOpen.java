package com.example.contract.simple;

import com.scalar.dl.ledger.asset.Asset;
import com.scalar.dl.ledger.contract.Contract;
import com.scalar.dl.ledger.database.Ledger;
import com.scalar.dl.ledger.exception.ContractContextException;
import java.util.Optional;
import javax.json.Json;
import javax.json.JsonObject;

public class SimpleOpen extends Contract {

  @Override
  public JsonObject invoke(Ledger ledger, JsonObject argument, Optional<JsonObject> properties) {
    if (!argument.containsKey("account") || !argument.containsKey("money")) {
      throw new ContractContextException("Please set 'account' and 'money' in the argument");
    }

    String accountId = argument.getString("account");
    int balance = argument.getInt("money");

    Optional<Asset> asset = ledger.get(accountId);

    if (asset.isPresent()) {
      throw new ContractContextException("Specified account already exists");
    } else {
      ledger.put(accountId, Json.createObjectBuilder().add("balance", balance).build());
    }

    return null;
  }
}
