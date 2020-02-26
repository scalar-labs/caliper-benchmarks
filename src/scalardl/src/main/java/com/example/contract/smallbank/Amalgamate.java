package com.example.contract.smallbank;

import com.scalar.dl.ledger.asset.Asset;
import com.scalar.dl.ledger.contract.Contract;
import com.scalar.dl.ledger.database.Ledger;
import com.scalar.dl.ledger.exception.ContractContextException;
import java.util.Optional;
import javax.json.Json;
import javax.json.JsonObject;
import javax.json.JsonObjectBuilder;

public class Amalgamate extends Contract {

  @Override
  public JsonObject invoke(Ledger ledger, JsonObject argument, Optional<JsonObject> properties) {
    if (!argument.containsKey(Const.KEY_SRC_CUSTOMER_ID)
        || !argument.containsKey(Const.KEY_DST_CUSTOMER_ID)) {
      throw new ContractContextException(
          "Please set "
              + Const.KEY_SRC_CUSTOMER_ID
              + " and "
              + Const.KEY_DST_CUSTOMER_ID
              + " in the argument");
    }

    String srcCustomerId = Integer.toString(argument.getInt(Const.KEY_SRC_CUSTOMER_ID));
    String dstCustomerId = Integer.toString(argument.getInt(Const.KEY_DST_CUSTOMER_ID));

    Optional<Asset> srcAsset = ledger.get(srcCustomerId);
    if (!srcAsset.isPresent()) {
      throw new ContractContextException(Const.ERR_NOT_FOUND);
    }
    Optional<Asset> destAsset = ledger.get(dstCustomerId);
    if (!destAsset.isPresent()) {
      throw new ContractContextException(Const.ERR_NOT_FOUND);
    }

    JsonObject srcData = srcAsset.get().data();
    JsonObject dstData = destAsset.get().data();
    int srcSavingsBalance = srcData.getInt(Const.KEY_SAVINGS_BALANCE);
    int dstCheckingBalance = dstData.getInt(Const.KEY_CHECKING_BALANCE);
    dstCheckingBalance += srcSavingsBalance;
    srcSavingsBalance = 0;

    JsonObjectBuilder newSrcData = Json.createObjectBuilder(srcData);
    JsonObjectBuilder newDstData = Json.createObjectBuilder(dstData);
    newSrcData.add(Const.KEY_SAVINGS_BALANCE, srcSavingsBalance);
    newDstData.add(Const.KEY_CHECKING_BALANCE, dstCheckingBalance);
    ledger.put(srcCustomerId, newSrcData.build());
    ledger.put(dstCustomerId, newDstData.build());

    return null;
  }
}
