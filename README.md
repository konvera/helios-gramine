# Helios-Gramine

# Quickstart

Build helios as a gramine SGX application, requires SGX, gramine and helios dependencies

```
SGX=1 make
```

Run Helios in SGX
```
gramine-sgx ./helios --execution-rpc https://eth-mainnet.g.alchemy.com/v2/{ALCHEMY_API_KEY}
```
