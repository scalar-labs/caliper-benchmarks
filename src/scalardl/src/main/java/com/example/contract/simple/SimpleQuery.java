package com.example.contract.simple;

import com.scalar.dl.ledger.asset.Asset;
import com.scalar.dl.ledger.asset.InternalAsset;
import com.scalar.dl.ledger.contract.Contract;
import com.scalar.dl.ledger.database.Ledger;
import com.scalar.dl.ledger.exception.ContractContextException;
import java.util.Optional;
import javax.json.JsonObject;

public class SimpleQuery extends Contract {

  @Override
  public JsonObject invoke(Ledger ledger, JsonObject argument, Optional<JsonObject> properties) {
    if (!argument.containsKey("query_key")) {
      throw new ContractContextException(
          "Please set 'query_key' with the querying account in the argument");
    }

    String accountId = argument.getString("query_key");

    Optional<Asset> asset = ledger.get(accountId);
    InternalAsset internal;
    if (asset.isPresent()) {
      internal = (InternalAsset) asset.get();
    } else {
      throw new ContractContextException("Specified account does not exist");
    }

    return internal.data();
  }
}
