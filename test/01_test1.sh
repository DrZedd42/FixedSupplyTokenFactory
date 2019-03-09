#!/bin/bash
# ----------------------------------------------------------------------------------------------
# Testing the smart contract
#
# Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2019. The MIT Licence.
# ----------------------------------------------------------------------------------------------

# echo "Options: [full|takerSell|takerBuy|exchange]"

MODE=${1:-full}

source settings
echo "---------- Settings ----------" | tee $TEST1OUTPUT
cat ./settings | tee -a $TEST1OUTPUT
echo "" | tee -a $TEST1OUTPUT

CURRENTTIME=`date +%s`
CURRENTTIMES=`perl -le "print scalar localtime $CURRENTTIME"`
START_DATE=`echo "$CURRENTTIME+45" | bc`
START_DATE_S=`perl -le "print scalar localtime $START_DATE"`
END_DATE=`echo "$CURRENTTIME+60*2" | bc`
END_DATE_S=`perl -le "print scalar localtime $END_DATE"`

printf "CURRENTTIME = '$CURRENTTIME' '$CURRENTTIMES'\n" | tee -a $TEST1OUTPUT
printf "START_DATE  = '$START_DATE' '$START_DATE_S'\n" | tee -a $TEST1OUTPUT
printf "END_DATE    = '$END_DATE' '$END_DATE_S'\n" | tee -a $TEST1OUTPUT

# Make copy of SOL file ---
# rsync -rp $SOURCEDIR/* . --exclude=Multisig.sol --exclude=test/
rsync -rp $SOURCEDIR/* . --exclude=Multisig.sol
# Copy modified contracts if any files exist
find ./modifiedContracts -type f -name \* -exec cp {} . \;

# --- Modify parameters ---
#`perl -pi -e "s/emit LogUint.*$//" $EXCHANGESOL`
# Does not work `perl -pi -e "print if(!/emit LogUint/);" $EXCHANGESOL`

DIFFS1=`diff -r -x '*.js' -x '*.json' -x '*.txt' -x 'testchain' -x '*.md' -x '*.sh' -x 'settings' -x 'modifiedContracts' $SOURCEDIR .`
echo "--- Differences $SOURCEDIR/*.sol *.sol ---" | tee -a $TEST1OUTPUT
echo "$DIFFS1" | tee -a $TEST1OUTPUT

solc_0.5.4 --version | tee -a $TEST1OUTPUT

echo "var tokenFactoryOutput=`solc_0.5.4 --allow-paths . --optimize --pretty-json --combined-json abi,bin,interface $TOKENFACTORYSOL`;" > $TOKENFACTORYJS
# ../scripts/solidityFlattener.pl --contractsdir=../contracts --mainsol=$TOKENFACTORYSOL --outputsol=$TOKENFACTORYFLATTENED --verbose | tee -a $TEST1OUTPUT


if [ "$MODE" = "compile" ]; then
  echo "Compiling only"
  exit 1;
fi

geth --verbosity 3 attach $GETHATTACHPOINT << EOF | tee -a $TEST1OUTPUT
loadScript("$TOKENFACTORYJS");
loadScript("lookups.js");
loadScript("functions.js");

var tokenFactoryAbi = JSON.parse(tokenFactoryOutput.contracts["$TOKENFACTORYSOL:$TOKENFACTORYNAME"].abi);
var tokenFactoryBin = "0x" + tokenFactoryOutput.contracts["$TOKENFACTORYSOL:$TOKENFACTORYNAME"].bin;
var tokenAbi = JSON.parse(tokenFactoryOutput.contracts["$TOKENFACTORYSOL:$TOKENNAME"].abi);

// console.log("DATA: tokenFactoryAbi=" + JSON.stringify(tokenFactoryAbi));
// console.log("DATA: tokenFactoryBin=" + JSON.stringify(tokenFactoryBin));
// console.log("DATA: tokenAbi=" + JSON.stringify(tokenAbi));


unlockAccounts("$PASSWORD");
printBalances();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var deployGroup1Message = "Deploy Group #1 - TokenFactory";
// -----------------------------------------------------------------------------
console.log("RESULT: ---------- " + deployGroup1Message + " ----------");
var tokenFactoryContract = web3.eth.contract(tokenFactoryAbi);
var tokenFactoryTx = null;
var tokenFactoryAddress = null;
var tokenFactory = tokenFactoryContract.new({from: deployer, data: tokenFactoryBin, gas: 6400000, gasPrice: defaultGasPrice},
  function(e, contract) {
    if (!e) {
      if (!contract.address) {
        tokenFactoryTx = contract.transactionHash;
      } else {
        tokenFactoryAddress = contract.address;
        addAccount(tokenFactoryAddress, "TokenFactory");
        addFactoryContractAddressAndAbi(tokenFactoryAddress, tokenFactoryAbi);
        console.log("DATA: var tokenFactoryAddress=\"" + tokenFactoryAddress + "\";");
        console.log("DATA: var tokenFactoryAbi=" + JSON.stringify(tokenFactoryAbi) + ";");
        console.log("DATA: var tokenFactory=eth.contract(tokenFactoryAbi).at(tokenFactoryAddress);");
      }
    }
  }
);
while (txpool.status.pending > 0) {
}
printBalances();
failIfTxStatusError(tokenFactoryTx, deployGroup1Message + " - TokenFactory");
console.log("RESULT: ");
printFactoryContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var deployGroup2Message = "Deploy Group #1 - Deploy Token";
var symbol = "TEST";
var name = "Test";
var decimals = 18;
var totalSupply = new BigNumber("1000000").shift(decimals);
var feeInEthers = new BigNumber(10).shift(18);
// -----------------------------------------------------------------------------
console.log("RESULT: ---------- " + deployGroup2Message + " ----------");
var deployToken_1Tx = tokenFactory.deployTokenContract(symbol, name, decimals, totalSupply, {from: deployer, value: feeInEthers, gas: 2000000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
var tokenContract = getTokenContractDeployed();
console.log("RESULT: tokenContract=#" + tokenContract.length + " " + JSON.stringify(tokenContract));
tokenAddress = tokenContract[0];
token = web3.eth.contract(tokenAbi).at(tokenAddress);
addAccount(tokenAddress, "Token '" + token.symbol() + "' '" + token.name() + "'");
addTokenContractAddressAndAbi(tokenAddress, tokenAbi);

printBalances();
console.log("RESULT: ");
printFactoryContractDetails();
console.log("RESULT: ");
printTokenContractDetails();
console.log("RESULT: ");

exit;

// -----------------------------------------------------------------------------
var deployGroup2Message = "Deploy Group #2";
// -----------------------------------------------------------------------------
console.log("RESULT: ---------- " + deployGroup2Message + " ----------");
var users = [user1, user2, user3];
var deployGroup2_Txs = [];
var userNumber = 1;
users.forEach(function(u) {
  for (i = 0; i < numberOfTokens; i++) {
    var tx = tokens[i].mint(u, new BigNumber(_tokenInitialDistributions[i]).shift(_tokenDecimals[i]), {from: deployer, gas: 2000000, gasPrice: defaultGasPrice});
    deployGroup2_Txs.push(tx);
    // tx = tokens[i].approve(dexzAddress, new BigNumber(_tokenInitialDistributions[i]).add(userNumber/10).shift(_tokenDecimals[i]), {from: u, gas: 2000000, gasPrice: defaultGasPrice});
    // deployGroup2_Txs.push(tx);
  }
  userNumber++;
});
while (txpool.status.pending > 0) {
}
printBalances();
deployGroup2_Txs.forEach(function(t) {
  failIfTxStatusError(t, deployGroup2Message + " - Distribute tokens and approve spending - " + t);
});
deployGroup2_Txs.forEach(function(t) {
  printTxData("", t);
});
console.log("RESULT: ");
printDexOneExchangeContractDetails();
console.log("RESULT: ");
for (i = 0; i < numberOfTokens; i++) {
  printTokenContractDetails(i);
  console.log("RESULT: ");
}
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var depositDividend1Message = "Deposit Dividends #1";
var dividends1 = new BigNumber(1000).shift(18);
// -----------------------------------------------------------------------------
console.log("RESULT: ---------- " + depositDividend1Message + " ----------");
var depositDividend1_1Tx = tokens[TKN].approve(tokens[DPT].address, dividends1, {from: deployer, gas: 2000000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
var depositDividend1_2Tx = tokens[DPT].depositDividends(tokens[TKN].address, dividends1, {from: deployer, gas: 2000000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
printBalances();
failIfTxStatusError(depositDividend1_1Tx, depositDividend1Message + " - deployer " + tokens[TKN].symbol() + ".approve(DPT, " + dividends1.shift(-18) + ")");
failIfTxStatusError(depositDividend1_2Tx, depositDividend1Message + " - deployer TKN.depositDividends(" + dividends1.shift(-18) + ")");
printTxData("depositDividend1_1Tx", depositDividend1_1Tx);
printTxData("depositDividend1_2Tx", depositDividend1_2Tx);
console.log("RESULT: ");
printDexOneExchangeContractDetails();
console.log("RESULT: ");
for (i = 0; i < numberOfTokens; i++) {
  printTokenContractDetails(i);
  console.log("RESULT: ");
}
console.log("RESULT: ");
}


exit;


// -----------------------------------------------------------------------------
var addOrders1Message = "Add Orders #1";
var ordersLoop;
for (var ordersLoop = 0; ordersLoop < 2; ordersLoop++) {
  var buyPrice1 = new BigNumber(0.00100).shift(18);
  var buyPrice2 = new BigNumber(0.00090).shift(18);
  var sellPrice1 = new BigNumber(0.00090).shift(18);
  var sellPrice2 = new BigNumber(0.00110).shift(18);
  var buyAmount = new BigNumber("100.00").shift(18);
  var sellAmount = new BigNumber("2000.00").shift(18);
  var expired = parseInt(new Date()/1000) - 60*60;
  var expiry = parseInt(new Date()/1000) + 60*60;
  var orders = [];
  var ordersTxs = [];
  if (ordersLoop == 0) {
    // orders.push({buySell: BUY, baseToken: tokenAddresses[ABC], quoteToken: tokenAddresses[WETH], price: new BigNumber(0.00100).shift(18), expiry: expired, amount: buyAmount, user: user2});
    // orders.push({buySell: BUY, baseToken: tokenAddresses[ABC], quoteToken: tokenAddresses[WETH], price: new BigNumber(0.00100).shift(18), expiry: expired, amount: buyAmount, user: user3});
    // orders.push({buySell: BUY, baseToken: tokenAddresses[ABC], quoteToken: tokenAddresses[WETH], price: new BigNumber(0.00130).shift(18), expiry: expiry, amount: buyAmount, user: user2});
    // orders.push({buySell: BUY, baseToken: tokenAddresses[ABC], quoteToken: tokenAddresses[WETH], price: new BigNumber(0.00120).shift(18), expiry: expiry, amount: buyAmount, user: user3});
    // orders.push({buySell: BUY, baseToken: tokenAddresses[ABC], quoteToken: tokenAddresses[WETH], price: new BigNumber(0.00100).shift(18), expiry: expiry, amount: buyAmount, user: user4});
    orders.push({buySell: BUY, baseToken: tokenAddresses[ABC], quoteToken: tokenAddresses[WETH], price: new BigNumber(0.00100).shift(18), expiry: expiry, amount: buyAmount, user: user5});
    // orders.push({buySell: BUY, baseToken: tokenAddresses[ABC], quoteToken: tokenAddresses[WETH], price: buyPrice2, expiry: expiry, amount: buyAmount, user: user2});
  } else if (ordersLoop == 1) {
    orders.push({buySell: SELL, baseToken: tokenAddresses[ABC], quoteToken: tokenAddresses[WETH], price: sellPrice1, expiry: expiry, amount: sellAmount, user: user6});
  } else {
    orders.push({buySell: SELL, baseToken: tokenAddresses[ABC], quoteToken: tokenAddresses[WETH], price: sellPrice2, expiry: expiry, amount: sellAmount, user: user4});
    orders.push({buySell: BUY, baseToken: tokenAddresses[ABC], quoteToken: tokenAddresses[WETH], price: buyPrice2, expiry: expiry, amount: buyAmount, user: user5});
  }
  // -----------------------------------------------------------------------------
  console.log("RESULT: ---------- " + addOrders1Message + " loop " + ordersLoop + " ----------");
  for (i = 0; i < orders.length; i++) {
    var order = orders[i];
    ordersTxs.push(dexz.trade(order.buySell, order.baseToken, order.quoteToken, order.price, order.expiry, order.amount, uiFeeAccount, {from: order.user, gas: 3000000, gasPrice: defaultGasPrice}));
    while (txpool.status.pending > 0) {
    }
  }
  printBalances();
  for (i = 0; i < orders.length; i++) {
    var order = orders[i];
    var ordersTx = ordersTxs[i];
    failIfTxStatusError(ordersTx, addOrders1Message + " - " + getShortAddressName(order.user) + " addOrder(" + (order.buySell == 0 ? "Buy" : "Sell") + ", " +
      getAddressSymbol(order.baseToken) + "/" + getAddressSymbol(order.quoteToken) + ", " + order.price.shift(-18) + ", +1h, " + order.amount.shift(-18) + ")");
  }
  for (i = 0; i < orders.length; i++) {
    var order = orders[i];
    var ordersTx = ordersTxs[i];
    printTxData("ordersTx[" + i + "]", ordersTx);
  }
  console.log("RESULT: ");
  printDexOneExchangeContractDetails();
  console.log("RESULT: ");
  for (i = 0; i < numberOfTokens; i++) {
    printTokenContractDetails(i);
    console.log("RESULT: ");
  }
  console.log("RESULT: ");
}


if (true) {
// -----------------------------------------------------------------------------
var approveAndCallMessage = "ApproveAndCall #1";
var buyAmount = new BigNumber(1500).shift(18);
// var data = "0xaabbccdd" + "1122334455667788990011223344556677889900112233445566778899001122" + \
//   "1222334455667788990011223344556677889900112233445566778899001122" + "1322334455667788990011223344556677889900112233445566778899001122" + \
//   "1422334455667788990011223344556677889900112233445566778899001122" + "1522334455667788990011223344556677889900112233445566778899001122" + \
//   "1622334455667788990011223344556677889900112233445566778899001122" + "1722334455667788990011223344556677889900112233445566778899001122";
var tradeData = dexz.trade.getData(BUY, tokenAddresses[ABC], tokenAddresses[WETH], buyPrice2, expiry, buyAmount, uiFeeAccount, {from: user5, gas: 3000000, gasPrice: defaultGasPrice});
console.log("RESULT: tradeData[Buy 1500 ABC/WETH]='" + tradeData + "'");
// -----------------------------------------------------------------------------
console.log("RESULT: ---------- " + approveAndCallMessage + " ----------");
var approveAndCall1_1Tx = tokens[ABC].approveAndCall(dexzAddress, buyAmount, tradeData, {from: user5, gas: 2000000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
printBalances();
failIfTxStatusError(approveAndCall1_1Tx, approveAndCallMessage + " - user5 " + tokens[ABC].symbol() + ".approveAndCall(dexz, " + buyAmount.shift(-18) + ", '" + tradeData + "')");
printTxData("approveAndCall1_1Tx", approveAndCall1_1Tx);
console.log("RESULT: ");
printDexOneExchangeContractDetails();
console.log("RESULT: ");
for (i = 0; i < numberOfTokens; i++) {
  printTokenContractDetails(i);
  console.log("RESULT: ");
}
console.log("RESULT: ");

}


exit;


if ("$MODE" == "full" || "$MODE" == "takerSell") {
  // -----------------------------------------------------------------------------
  var takerSell1Message = "Taker Sell #1";
  var sellAmount = new BigNumber(1500).shift(18);
  // -----------------------------------------------------------------------------
  console.log("RESULT: ---------- " + takerSell1Message + " ----------");
  var takerSell1_1Tx = tokens[ABC].approve(dexzAddress, sellAmount, {from: user5, gas: 2000000, gasPrice: defaultGasPrice});
  while (txpool.status.pending > 0) {
  }
  var orderKeys = [dexz.ordersIndex(0), dexz.ordersIndex(1)];
  var takerSell1_2Tx = dexz.takerSell(orderKeys, sellAmount, {from: user5, gas: 2000000, gasPrice: defaultGasPrice});
  while (txpool.status.pending > 0) {
  }
  printBalances();
  failIfTxStatusError(takerSell1_1Tx, takerSell1Message + " - user5 " + tokens[ABC].symbol() + ".approve(dexz, " + sellAmount.shift(-18) + ")");
  failIfTxStatusError(takerSell1_2Tx, takerSell1Message + " - user5 dexz.takerSell(" + JSON.stringify(orderKeys) + ", " + sellAmount.shift(-18) + ")");
  printTxData("takerSell1_1Tx", takerSell1_1Tx);
  printTxData("takerSell1_2Tx", takerSell1_2Tx);
  console.log("RESULT: ");
  printDexOneExchangeContractDetails();
  console.log("RESULT: ");
  for (i = 0; i < numberOfTokens; i++) {
    printTokenContractDetails(i);
    console.log("RESULT: ");
  }
  console.log("RESULT: ");


  // -----------------------------------------------------------------------------
  var takerSell2Message = "Taker Sell #2";
  var sellAmount = new BigNumber(1000).shift(18);
  // -----------------------------------------------------------------------------
  console.log("RESULT: ---------- " + takerSell2Message + " ----------");
  var takerSell2_1Tx = tokens[ABC].approve(dexzAddress, sellAmount, {from: user5, gas: 2000000, gasPrice: defaultGasPrice});
  while (txpool.status.pending > 0) {
  }
  var orderKeys = [dexz.ordersIndex(0), dexz.ordersIndex(1)];
  var takerSell2_2Tx = dexz.takerSell(orderKeys, sellAmount, {from: user5, gas: 2000000, gasPrice: defaultGasPrice});
  while (txpool.status.pending > 0) {
  }
  printBalances();
  failIfTxStatusError(takerSell2_1Tx, takerSell2Message + " - user5 " + tokens[ABC].symbol() + ".approve(dexz, " + sellAmount.shift(-18) + ")");
  failIfTxStatusError(takerSell2_2Tx, takerSell2Message + " - user5 dexz.takerSell(" + JSON.stringify(orderKeys) + ", " + sellAmount.shift(-18) + ")");
  printTxData("takerSell2_1Tx", takerSell2_1Tx);
  printTxData("takerSell2_2Tx", takerSell2_2Tx);
  console.log("RESULT: ");
  printDexOneExchangeContractDetails();
  console.log("RESULT: ");
  for (i = 0; i < numberOfTokens; i++) {
    printTokenContractDetails(i);
    console.log("RESULT: ");
  }
  console.log("RESULT: ");
}


if ("$MODE" == "full" || "$MODE" == "takerBuy") {
  // -----------------------------------------------------------------------------
  var takerBuy1Message = "Taker Buy #1";
  var buyAmount = new BigNumber(1000).shift(18);
  // -----------------------------------------------------------------------------
  console.log("RESULT: ---------- " + takerBuy1Message + " ----------");
  var takerBuy1_1Tx = tokens[WETH].approve(dexzAddress, buyAmount, {from: user6, gas: 2000000, gasPrice: defaultGasPrice});
  while (txpool.status.pending > 0) {
  }
  // var orderKey = user2Wallet.getOrderKeyByIndex(user2Wallet.getNumberOfOrders() - 1);
  var orderKeys = [dexz.ordersIndex(2), dexz.ordersIndex(3)];
  var takerBuy1_2Tx = dexz.takerBuy(orderKeys, buyAmount, {from: user6, gas: 2000000, gasPrice: defaultGasPrice});
  while (txpool.status.pending > 0) {
  }
  printBalances();
  failIfTxStatusError(takerBuy1_1Tx, takerBuy1Message + " - user6 " + tokens[WETH].symbol() + ".approve(dexz, " + buyAmount.shift(-18) + ")");
  failIfTxStatusError(takerBuy1_2Tx, takerBuy1Message + " - user6 dexz.takerBuy(" + JSON.stringify(orderKeys) + ", " + buyAmount.shift(-18) + ")");
  printTxData("takerBuy1_1Tx", takerBuy1_1Tx);
  printTxData("takerBuy1_2Tx", takerBuy1_2Tx);
  console.log("RESULT: ");
  printDexOneExchangeContractDetails();
  console.log("RESULT: ");
  for (i = 0; i < numberOfTokens; i++) {
    printTokenContractDetails(i);
    console.log("RESULT: ");
  }
  console.log("RESULT: ");


  // -----------------------------------------------------------------------------
  var takerBuy2Message = "Taker Buy #2";
  var buyAmount = new BigNumber(1000).shift(18);
  // -----------------------------------------------------------------------------
  console.log("RESULT: ---------- " + takerBuy2Message + " ----------");
  var takerBuy2_1Tx = tokens[WETH].approve(dexzAddress, buyAmount, {from: user6, gas: 2000000, gasPrice: defaultGasPrice});
  while (txpool.status.pending > 0) {
  }
  // var orderKey = user2Wallet.getOrderKeyByIndex(user2Wallet.getNumberOfOrders() - 1);
  var orderKeys = [dexz.ordersIndex(2), dexz.ordersIndex(3)];
  var takerBuy2_2Tx = dexz.takerBuy(orderKeys, buyAmount, {from: user6, gas: 2000000, gasPrice: defaultGasPrice});
  while (txpool.status.pending > 0) {
  }
  printBalances();
  failIfTxStatusError(takerBuy2_1Tx, takerBuy2Message + " - user6 " + tokens[WETH].symbol() + ".approve(dexz, " + buyAmount.shift(-18) + ")");
  failIfTxStatusError(takerBuy2_2Tx, takerBuy2Message + " - user6 dexz.takerBuy(" + JSON.stringify(orderKeys) + ", " + buyAmount.shift(-18) + ")");
  printTxData("takerBuy2_1Tx", takerBuy2_1Tx);
  printTxData("takerBuy2_2Tx", takerBuy2_2Tx);
  console.log("RESULT: ");
  printDexOneExchangeContractDetails();
  console.log("RESULT: ");
  for (i = 0; i < numberOfTokens; i++) {
    printTokenContractDetails(i);
    console.log("RESULT: ");
  }
  console.log("RESULT: ");
}


if ("$MODE" == "fullx" || "$MODE" == "exchange") {
  // -----------------------------------------------------------------------------
  var exchange1Message = "Exchange #1";
  var keys = [dexz.ordersIndex(0), dexz.ordersIndex(1)];
  console.log("RESULT: keys=" + JSON.stringify(keys));
  var baseTokens = [new BigNumber(1000).shift(18), new BigNumber(1000).shift(18)];
  console.log("RESULT: baseTokens=" + JSON.stringify(baseTokens));
  var quoteTokens = [new BigNumber(1).shift(18), new BigNumber(1).shift(18)];
  console.log("RESULT: quoteTokens=" + JSON.stringify(quoteTokens));
  var cpty = [user3, user1];
  console.log("RESULT: cpty=" + JSON.stringify(cpty));
  var tokenAddresses = [tokenAddresses[ABC], tokenAddresses[WETH]];
  console.log("RESULT: tokenAddresses=" + JSON.stringify(tokenAddresses));
  // -----------------------------------------------------------------------------
  console.log("RESULT: ---------- " + exchange1Message + " ----------");
  var exchange1_1Tx = dexz.exchange(keys, baseTokens, quoteTokens, cpty, tokenAddresses, {from: deployer, gas: 2000000, gasPrice: defaultGasPrice});
  while (txpool.status.pending > 0) {
  }
  printBalances();
  failIfTxStatusError(exchange1_1Tx, exchange1Message + " - deployer dexz.exchange(...)");
  printTxData("exchange1_1Tx", exchange1_1Tx);
  console.log("RESULT: ");
  printDexOneExchangeContractDetails();
  console.log("RESULT: ");
  for (i = 0; i < numberOfTokens; i++) {
    printTokenContractDetails(i);
    console.log("RESULT: ");
  }
  console.log("RESULT: ");
}


EOF
grep "DATA: " $TEST1OUTPUT | sed "s/DATA: //" > $DEPLOYMENTDATA
cat $DEPLOYMENTDATA
grep "RESULT: " $TEST1OUTPUT | sed "s/RESULT: //" > $TEST1RESULTS
cat $TEST1RESULTS
egrep -e "tokenTx.*gasUsed|ordersTx.*gasUsed" $TEST1RESULTS