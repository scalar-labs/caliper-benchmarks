package com.scalar.tool;

import java.io.IOException;
import java.io.Reader;
import java.lang.reflect.Array;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.cert.CertificateException;
import java.security.InvalidKeyException;
import java.security.PrivateKey;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Map;
import java.util.concurrent.Callable;
import java.util.concurrent.TimeUnit;
import java.util.List;
import java.util.Random;
import java.util.stream.Collectors;

import org.hyperledger.fabric.gateway.Contract;
import org.hyperledger.fabric.gateway.ContractEvent;
import org.hyperledger.fabric.gateway.ContractException;
import org.hyperledger.fabric.gateway.DefaultCheckpointers;
import org.hyperledger.fabric.gateway.DefaultCommitHandlers;
import org.hyperledger.fabric.gateway.DefaultQueryHandlers;
import org.hyperledger.fabric.gateway.Gateway;
import org.hyperledger.fabric.gateway.Identities;
import org.hyperledger.fabric.gateway.Identity;
import org.hyperledger.fabric.gateway.Network;
import org.hyperledger.fabric.gateway.Transaction;
import org.hyperledger.fabric.gateway.Wallet;
import org.hyperledger.fabric.gateway.Wallets;
import org.hyperledger.fabric.gateway.spi.Checkpointer;
import org.hyperledger.fabric.sdk.BlockEvent;
import org.hyperledger.fabric.sdk.exception.InvalidArgumentException;
import org.hyperledger.fabric.sdk.Peer;
import org.hyperledger.fabric.sdk.ProposalResponse;
import org.hyperledger.fabric.sdk.helper.Config;

public final class FabricClientService {
  private Random rand;
  private String networkConfigPath;
  private String commitWaitPolicy;
  private Gateway.Builder gatewayBuilder;
  private Gateway gateway;
  private Network network;
  private Wallet wallet;
  private List<List<Peer>> peers;

  public FabricClientService(String networkConfigPath) {
    this(networkConfigPath, "NONE");
  }

  public FabricClientService(String networkConfigPath, String commitWaitPolicy) {
    this.rand = new Random();
    this.networkConfigPath = networkConfigPath;
    this.commitWaitPolicy = commitWaitPolicy;
    this.gatewayBuilder = Gateway.createBuilder();
    this.wallet = Wallets.newInMemoryWallet();
    this.peers = new ArrayList<List<Peer>>();

    try {
      prepareGateway(gatewayBuilder);
      populateWallet(wallet);
      setupNetwork();
    } catch (Exception e) {
      // TODO
      e.printStackTrace();
    }
  }

  private void prepareGateway(Gateway.Builder gatewayBuilder)
    throws IOException, CertificateException, InvalidKeyException {
    Identity identity = newOrg1UserIdentity();
    gatewayBuilder.identity(identity);
    gatewayBuilder.commitHandler(DefaultCommitHandlers.valueOf(this.commitWaitPolicy));
    gatewayBuilder.networkConfig(Paths.get(this.networkConfigPath));
    gatewayBuilder.commitTimeout(1, TimeUnit.MINUTES);
  }

  private void populateWallet(Wallet wallet)
    throws IOException, CertificateException, InvalidKeyException {
    Identity identity = newOrg1UserIdentity();
    wallet.put("User1", identity);
  }

  private static X509Certificate readX509Certificate(final Path certificatePath)
    throws IOException, CertificateException {
    try (Reader certificateReader = Files.newBufferedReader(certificatePath, StandardCharsets.UTF_8)) {
        return Identities.readX509Certificate(certificateReader);
    }
  }

  private static PrivateKey getPrivateKey(final Path privateKeyPath)
    throws IOException, InvalidKeyException {
    try (Reader privateKeyReader = Files.newBufferedReader(privateKeyPath, StandardCharsets.UTF_8)) {
        return Identities.readPrivateKey(privateKeyReader);
    }
  }

  private static Identity newOrg1UserIdentity()
    throws IOException, CertificateException, InvalidKeyException {
    // TODO: should get the paths from config option or file
    Path credentialPath = Paths.get(
      "networks", "fabric", "config_swarm_raft", "crypto-config",
      "peerOrganizations", "org1.example.com", "users", "User1@org1.example.com", "msp");

    Path certificatePath = credentialPath.resolve(
      Paths.get("signcerts", "User1@org1.example.com-cert.pem"));
    X509Certificate certificate = readX509Certificate(certificatePath);

    Path privateKeyPath = credentialPath.resolve(Paths.get("keystore", "key.pem"));
    PrivateKey privateKey = getPrivateKey(privateKeyPath);

    return Identities.newX509Identity("Org1MSP", certificate, privateKey);
  }

  private void setupNetwork() {
    this.gateway = gatewayBuilder.connect();
    this.network = gateway.getNetwork("mychannel");
    Collection<String> organizations = network.getChannel().getPeersOrganizationMSPIDs();
    organizations.forEach(
      organization -> {
        try {
          ArrayList<Peer> peersInOrganization
           = new ArrayList<Peer>(network.getChannel()
              .getPeersForOrganization(organization)
              .stream()
              .collect(Collectors.toList()));
          peers.add(peersInOrganization);
        } catch (InvalidArgumentException e) {
          // TODO
        }
    });    
  }
  
  private List<Peer> generateEndorsers() {
    List<Peer> endorsers = new ArrayList<Peer>();
    peers.forEach(
      peersInOrganization -> {
        endorsers.add(peersInOrganization.get(
          this.rand.nextInt(peersInOrganization.size())));
      }
    );
    return endorsers;
  }

  public void executeContract(String contractName, String functionName, String... args)
    throws ContractException {
    List<Peer> endorsers = generateEndorsers();
    Contract contract = network.getContract(contractName);
    Transaction transaction = contract.createTransaction(functionName);
    // transactionInvocation = new TransactionInvocation(transaction);
    // String[] args = newStringArray(parseJsonArray(argsJson));
    transaction.setEndorsingPeers(endorsers);
    try {
      byte[] result = transaction.submit(args);
    } catch (Exception e) {
      throw new ContractException("Contract execution failed.", e); 
    }
  }
}
