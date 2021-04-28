package com.scalar.tool;

import com.scalar.tool.FabricClientService;

import com.google.inject.Guice;
import com.google.inject.Injector;
import com.scalar.dl.client.config.ClientConfig;
import com.scalar.dl.client.exception.ClientException;
import com.scalar.dl.client.service.ClientModule;
import com.scalar.dl.client.service.ClientService;
import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import javax.json.Json;
import javax.json.JsonObject;
import picocli.CommandLine;
import picocli.CommandLine.Command;

import org.hyperledger.fabric.gateway.ContractException;

@Command(name = "smallbank-loader", description = "Create accounts.")
public class SmallBankLoader implements Callable<Integer> {

  @CommandLine.Option(
    names = {"--network-config"},
    required = true,
    paramLabel = "NETWORK_CONFIG",
    description = "A configuration file for Fabric Network.")
  private String networkConfig;

  @CommandLine.Option(
      names = {"--num-accounts"},
      required = false,
      paramLabel = "NUM_ACCOUNTS",
      description = "The number of target accounts.")
  private int numAccounts = 10000;

  @CommandLine.Option(
      names = {"--num-threads"},
      required = false,
      paramLabel = "NUM_THREADS",
      description = "The number of threads to run.")
  private int numThreads = 1;

  @CommandLine.Option(
      names = {"-h", "--help"},
      usageHelp = true,
      description = "display the help message.")
  boolean helpRequested;

  private static AtomicInteger counter = new AtomicInteger(0);
  private static int DEFAULT_BALANCE = 100000;

  public static void main(String[] args) {
    int exitCode = new CommandLine(new SmallBankLoader()).execute(args);
    System.exit(exitCode);
  }

  @Override
  public Integer call() throws Exception {
    // TODO: switch scalar and fabric
    // Injector injector =
    //     Guice.createInjector(new ClientModule(new ClientConfig(new File(properties))));
    // ClientService service = injector.getInstance(ClientService.class);

    ExecutorService executor = Executors.newFixedThreadPool(numThreads);
    final long start = System.currentTimeMillis();
    long from = start;
    for (int i = 0; i < numThreads; ++i) {
      executor.execute(
          () -> {
            FabricClientService service = new FabricClientService(networkConfig);
            while (true) {
              String id = Integer.toString(counter.getAndIncrement());
              /*
              JsonObject jsonArgument =
                  Json.createObjectBuilder()
                      .add("id", id)
                      .add("amount", DEFAULT_BALANCE)
                      .build();
              */
              try {
                if (counter.get() > numAccounts) {
                  break;
                }
                /*
                service.executeContract(contractId, jsonArgument, Optional.empty());
                */
                List<String> args = new ArrayList<>();
                args.add(id);
                args.add("John Doe");
                args.add(Integer.toString(DEFAULT_BALANCE));
                args.add(Integer.toString(DEFAULT_BALANCE));
                service.executeContract("smallbank", "create_account",
                  args.toArray(new String[args.size()]));
              } catch (ClientException e) {
                e.printStackTrace();
              } catch (ContractException e) {
                // e.printStackTrace();
              }
            }
          });
    }

    while (true) {
      if (counter.get() > numAccounts) {
        break;
      }
      System.out.println(counter.get() + " assets are loaded.");

      try {
        Thread.sleep(1000);
      } catch (InterruptedException e) {
        Thread.interrupted();
      }
    }

    executor.shutdown();
    executor.awaitTermination(10, TimeUnit.SECONDS);

    return 0;
  }
}
