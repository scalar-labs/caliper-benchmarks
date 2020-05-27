package com.example.contract.token;

import com.scalar.dl.ledger.asset.Asset;
import com.scalar.dl.ledger.contract.Contract;
import com.scalar.dl.ledger.database.Ledger;
import com.scalar.dl.ledger.exception.ContractContextException;
import java.util.Optional;
import javax.json.Json;
import javax.json.JsonObject;
import javax.json.JsonObjectBuilder;

public class SendToken extends Contract {

  @Override
  public JsonObject invoke(Ledger ledger, JsonObject argument, Optional<JsonObject> properties) {
    if (!argument.containsKey(Const.KEY_SRC_USER_ID)
        || !argument.containsKey(Const.KEY_DST_USER_ID)
        || !argument.containsKey(Const.KEY_AMOUNT)) {
      throw new ContractContextException(
          "Please set "
              + Const.KEY_SRC_USER_ID
              + ", "
              + Const.KEY_DST_USER_ID
              + " and "
              + Const.KEY_AMOUNT
              + " in the argument");
    }

    String srcUserId = Integer.toString(argument.getInt(Const.KEY_SRC_USER_ID));
    String dstUserId = Integer.toString(argument.getInt(Const.KEY_DST_USER_ID));
    int amount = argument.getInt(Const.KEY_AMOUNT);

    Optional<Asset> srcAsset = ledger.get(srcUserId);
    if (!srcAsset.isPresent()) {
      throw new ContractContextException(Const.ERR_NOT_FOUND);
    }
    Optional<Asset> dstAsset = ledger.get(dstUserId);
    if (!dstAsset.isPresent()) {
      throw new ContractContextException(Const.ERR_NOT_FOUND);
    }

    JsonObject srcData = srcAsset.get().data();
    JsonObject dstData = dstAsset.get().data();
    int srcBalance = srcData.getInt(Const.KEY_TOKEN_BALANCE);
    int dstBalance = dstData.getInt(Const.KEY_TOKEN_BALANCE);
    srcBalance -= amount;
    dstBalance += amount;

    JsonObjectBuilder newSrcData = Json.createObjectBuilder(srcData);
    JsonObjectBuilder newDstData = Json.createObjectBuilder(dstData);
    newSrcData.add(Const.KEY_TOKEN_BALANCE, srcBalance);
    newDstData.add(Const.KEY_TOKEN_BALANCE, dstBalance);
    ledger.put(srcUserId, newSrcData.build());
    ledger.put(dstUserId, newDstData.build());

    return null;
  }
}
