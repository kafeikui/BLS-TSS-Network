# Extending DKG Scenario Tests

Prior to this test suite, we started with an empty network and 5 newly registered nodes to test various commitDkg() scenarios. This test suite extends the test cases to cover more scenarios.
Specifically, we set up various inital states of the network and then call nodeQuit() and nodeRegister() to trigger various grouping and rebalancing behaviors. We then assert the expected network state after each commitDkg() call, as well as making sure that group.epoch is incrementing correctly during the various steps.

Note: groupMaxCapacity is set to 6 instead of 10 to simplify setup.

## Rebalance Tests

`Regroup Single (5) -> nodeQuit`
group_0: 5 members
1 member of group_0 wants to exit the network
Then, controller will let 4 members left in group_0 do dkg as 4 > 3 which is the threshold
i.e. the group still meet the grouping condition
after that, in happy path group_0 will be functional with 4 members.

`Rebalance Two Groups (5,3) -> nodeQuit -> 3,4)`
group_0: 5 members
group_1: 3 members
1 member of group_1 wants to exist the network.
Then, controller will let group_1 which has 2 remaining members rebalance with group_0.
Result: group_0 (3 members), group_1 (4 members) are both functional.

## Grouping Tests

`(6,6) -> nodeRegister -> (3,6,4)`
group_0: 6 members
group_1: 6 members
A new node calls nodeRegister.
Controller should create a new group (group_2), add the new node into group_2, and then rebalance between group_0 and group_2.
Final network status should be (3,6,4), all functional, group_0 and group_1 should be grouped before next round of commitDkg.

`(3,3) -> nodeRegister -> (3,3,1)`
group_0: 3 members
group_1: 3 members
A new node calls nodeRegister
Controller should create a new group_2, add the new node into group_2, then try to rebalance.
Final network status should be (3,3,1) with group_2 not yet functional.

`ideal number of groups` (How do i get these network into state (3,3,3,3,3)
(5 groups) group 0-4 have 3 members each (3,3,3,3,3)
A new node calls nodeRegister
Controller should add new node into group_0 resulting in network state (4,3,3,3,3).
group_0 should be functional.

`ideal number of groups at max capacity`
(5 groups) group 0-4 have 6 members each (6,6,6,6,6)
A new node calls node register.
Controller should create a new group (group_5), add the new node to group_5, and then rebalance between group_0 and group_5.
Resulting network state should be (3,6,6,6,6,4) group_0 should be functional.

`(6,3) -> group_1 nodeQuit -> (4,4)`
This may looks similar to the first case, but please note that the paths to initial status (3,6) and (6,6,6,6,6) are different and they are both reachable in real cases.

group_0: 6 members
group_1: 3 members
member in group_1 called nodeQuit.
Then, the controller should rebalance between group_0 and group_2,
Resulting network state should be (4,4)
Borth group_0 and group_1 should be functional.

`(6,3) -> group_0 nodeQuit -> (5,3)`
group_0: 6 members
group_1: 3 members
member in group_0 calls nodeQuit.
Then, the controller should emitDkgEvent for group_0 with the 5 remaining remmbers.
Resulting network state should be (5,3)
Group_0 should be functional.

---

## Generating DKG Public Keys

We can generate DKG public keys using the bn254.rs file in the threshold-bls crate. This file can be modified to print out the serialized DKG public keys. The DKG public keys are used to register nodes to the network.

```bash
cd /Users/zen/dev/pr/BLS-TSS-Network/crates/threshold-bls/src/curve
bn
cargo test --test serialize_field

# prevent supression of output
cargo test -- --nocapture

# Run only a specific unit test
cargo test serialize_group -- --nocapture

# Note: investigate /Users/zen/dev/pr/BLS-TSS-Network/crates/threshold-bls/src/test_bls.rs
```

## Modifying bn254.rs to generate DKG Public Keys

```rust

// serialize_group_test::<G1>(32); // line 436 commented out

// line 441
use ethers_core::{types::U256, utils::hex}; // ! new

    fn serialize_group_test<E: Element>(size: usize) {
        let empty = bincode::deserialize::<E>(&[]);
        assert!(empty.is_err());

        let rng = &mut rand::thread_rng();
        let sig = E::rand(rng);
        let ser = bincode::serialize(&sig).unwrap();
        // println!("{:?}", ser); // print serialized value
        println!("bytes DKGPubkey1 = hex{:?}", hex::encode(ser.clone()));

        assert_eq!(ser.len(), size);

        let de: E = bincode::deserialize(&ser).unwrap();
        assert_eq!(de, sig);
    }
```

## partialPublic key vs DKGPublicKey vs publicKey

DKGPublicKey

- Used for interaction between DKG proccess.
- Each node generates one for itself a single time and uses it to register to network.
- Key is fixed for the life of the node.

publicKey / partialPublicKey

- Are generated by the DKG proccess.
- Both keys are commited during commitDkg function call.
- The nodes receive a grouping event, and then they participate in dkg and generate the two keys.

Sample flow

- 3 nodes call nodeRegister()
- controller emits event.
- all nodes receive the event: which container nodeIdAddress, DKGPublicKey.
- The nodes know which nodes to talk to from nodeIdAddress in the emitted event.
- Based off the above info, all nodes generate apartialPublicKey and publicKey
- Node all all commitDkg()
