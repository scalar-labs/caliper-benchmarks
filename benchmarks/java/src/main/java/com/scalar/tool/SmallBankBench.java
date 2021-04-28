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
import java.util.Collections;
import java.util.List;
import java.util.Optional;
import java.util.Random;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import javax.json.Json;
import javax.json.JsonObject;
import picocli.CommandLine;
import picocli.CommandLine.Command;

import org.hyperledger.fabric.gateway.ContractException;

@Command(name = "smallbank-bench", description = "Execute smallbank concurrently.")
public class SmallBankBench implements Callable<Integer> {

  @CommandLine.Option(
    names = {"--network-config"},
    required = true,
    paramLabel = "NETWORK_CONFIG",
    description = "A configuration file for Fabric Network.")
  private String networkConfig;

  @CommandLine.Option(
    names = {"--commit-wait-policy"},
    required = false,
    paramLabel = "COMMIT_WAIT_POLICY",
    description = "A waiting policy after submitting a transaction. (e.g., NETWORK_SCOPE_ALLFORTX)")
  private String commitWaitPolicy = "NONE";

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
      names = {"--duration"},
      required = false,
      paramLabel = "DURATION",
      description = "The duration of benchmark in seconds")
  private int duration = 200;

  @CommandLine.Option(
      names = {"--ramp-up-time"},
      required = false,
      paramLabel = "RAMP_UP_TIME",
      description = "The ramp up time in seconds.")
  private int rampUpTime = 60;

  @CommandLine.Option(
      names = {"-h", "--help"},
      usageHelp = true,
      description = "display the help message.")
  boolean helpRequested;

  private static AtomicInteger counter = new AtomicInteger();
  private static AtomicInteger totalCounter = new AtomicInteger();
  private static AtomicLong latencyTotal = new AtomicLong();
  private static AtomicInteger errorCounter = new AtomicInteger();

  public static void main(String[] args) {
    int exitCode = new CommandLine(new SmallBankBench()).execute(args);
    System.exit(exitCode);
  }

  private static final List<String> OperationTypes;
  static {
    List<String> types = new ArrayList<String>();
    types.add("transact_savings");
    types.add("deposit_checking");
    types.add("send_payment");
    types.add("write_check");
    types.add("amalgamate");
    OperationTypes = Collections.unmodifiableList(types);
  }

  List<String> generateTask(Random rand) {
    List<String> taskParams = new ArrayList<String>();
    String operation = OperationTypes.get(rand.nextInt(OperationTypes.size()));
    int account1 = rand.nextInt(numAccounts);
    int account2 = rand.nextInt(numAccounts);
    if (account2 == account1) {
      account2 = (account2 + 1) % numAccounts;
    }
    int amount = rand.nextInt(100) + 1;

    taskParams.add(operation);
    switch (operation) {
      case "transact_savings":
      case "deposit_checking":
      case "write_check":
        taskParams.add(Integer.toString(amount));
        taskParams.add(Integer.toString(account1));
        break;
      case "send_payment":
        taskParams.add(Integer.toString(amount));
        taskParams.add(Integer.toString(account1));
        taskParams.add(Integer.toString(account2));
        break;
      case "amalgamate":
        taskParams.add(Integer.toString(account1));
        taskParams.add(Integer.toString(account2));
        break;
      default:
    }

    return taskParams;
  }

  @Override
  public Integer call() throws Exception {
    // !!! Scalar DL
    // Injector injector =
    //     Guice.createInjector(new ClientModule(new ClientConfig(new File(properties))));
    // ClientService service = injector.getInstance(ClientService.class);
    // !!! TODO: What is injector?

    long durationMillis = duration * 1000;
    long rampUpTimeMillis = rampUpTime * 1000;

    AtomicBoolean isRunning = new AtomicBoolean(true);
    ExecutorService executor = Executors.newFixedThreadPool(numThreads);
    Random rand = new Random();
    final long start = System.currentTimeMillis();
    long from = start;
    for (int i = 0; i < numThreads; ++i) {
      executor.execute(
          () -> {
            // Fabric specific setup
            FabricClientService service = new FabricClientService(networkConfig, commitWaitPolicy);
            while (isRunning.get()) {
              int fromId = rand.nextInt(numAccounts);
              int toId = rand.nextInt(numAccounts);
              if (toId == fromId) {
                toId = (toId + 1) % numAccounts;
              }
              int amount = rand.nextInt(100) + 1;
              List<String> taskParams = generateTask(rand);

              try {
                long eachStart = System.currentTimeMillis();
                String operation = taskParams.remove(0);
                service.executeContract("smallbank", operation,
                  taskParams.toArray(new String[taskParams.size()]));
                long eachEnd = System.currentTimeMillis();
                counter.incrementAndGet();
                if (System.currentTimeMillis() >= start + rampUpTimeMillis) {
                  totalCounter.incrementAndGet();
                  latencyTotal.addAndGet(eachEnd - eachStart);
                }
              } catch (ClientException e) {
                errorCounter.incrementAndGet();
                // e.printStackTrace();
              } catch (ContractException e) { // for Fabric
                errorCounter.incrementAndGet();
                // e.printStackTrace();
              } catch (Exception e) {
                System.out.println("An error ocurred in a thread.");
                e.printStackTrace();
                System.exit(-1);
              }
            }
          });
    }

    long end = start + rampUpTimeMillis + durationMillis;
    while (true) {
      long to = System.currentTimeMillis();
      if (to >= end) {
        isRunning.set(false);
        break;
      }
      System.out.println(((double) counter.get() * 1000 / (to - from)) + " rps");
      counter.set(0);
      from = System.currentTimeMillis();

      try {
        Thread.sleep(1000);
      } catch (InterruptedException e) {
        Thread.interrupted();
      }
    }
    System.out.println(
        "TPS: " + (double) totalCounter.get() * 1000 / (end - start - rampUpTimeMillis));
    System.out.println("Average-Latency(ms): " + (double) latencyTotal.get() / totalCounter.get());
    System.out.println("Error counts: " + errorCounter.get());

    executor.shutdown();
    executor.awaitTermination(10, TimeUnit.SECONDS);

    return 0;
  }
}