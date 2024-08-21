// message PassScoreToRoundContract {
//     checked_address: Address;
//     return_score: Int as uint64;
// }
// // ===== Data Struct ===== //
 
// struct PayloadData {
//     vipLevel: Int as uint8;
//     timestamp: Int as uint32;
//     signature: Slice;
// }

// struct IdoData {
//     index: Int as uint64;
//     this_contract_jettonWallet: Address;
//     total_score: Int as coins;
//     parameter: Int as uint16;
// }

struct ClaimRecord {
    ethAddressInt: Int;           // ETH address as integer
    claimedTonAddress: Address;   //Jetton Master Wallet Address
    claimedAmount: Int as coins;
    claimedAt: Int as uint32;
}

struct ClaimInfoGet {    
    contractOwner: Address;
    claimUserCount: Int as uint32;    
    // contractBalance: Int as coins ;
    publicKey: Int;
    projectCoinAddress: Address;
    endTime: Int as uint32;
    claimTime: Int as uint32;
    claimedAmount: Int as coins;
}

message TransferEvent {
    eth_address: Int;
    sender_address: Address;
    jetton_amount: Int as coins;
    ido_action: String;
    action_message: String;
    idoTimestamp: Int as uint32;
}

message BalanceCorrectionEvent {
    eth_address: Int;
    claim_address: Address;
    jetton_amount: Int as coins;
    action: String;
    timestamp: Int as uint32;
}

// ================================================================================ //
// message UserIdo {
//     from: Address;
//     amount: Int as coins;
// }

// message Refund {
//     from: Address;
//     amount: Int as coins;
// }

message Claim {
    claimAmount: Int as coins; // change to coins
    timestamp: Int as uint32;
    ethAddressInt: Int; // add eth address int mapping
    signature: Slice;
}

// message Redeem {
//     queryId: Int as uint64;
//     project_id: Int as uint16;
// }

// message GetWeighted {
//     // ===== on-chain fetch ===== //
//     applied_user_address: Address;
// }


// message SetPublicKey{
//     publicKey: Int;
// }

// message SetIDOTimes {
//     claimTime: Int as uint32;
//     endTime: Int as uint32;
// }

message WithdrawFunds {
    destination: Address;
    amount: Int as coins;
}

// message TestSignature {
//     forward_payload: Slice as remaining; 
// }

// message SetProjectInfo {
//     price: Int as uint32;
//     targetAmount: Int as coins;
//     vip1Allocation: Int as coins;
//     vip2Allocation: Int as coins;
//     vip3Allocation: Int as coins;
//     vip1Percent: Int as uint32;
//     vip2Percent: Int as uint32;
//     vip3Percent: Int as uint32;
//     startTime: Int as uint32;
//     endSellTime: Int as uint32;
//     protectTime: Int as uint32;
//     claimTime: Int as uint32;
//     raiseStatus: Int as uint16;
// }

// message AdminCorrectRecord {
//     userClaimAddress: Address;
//     userAmount: Int as coins;   
// }

message SetProjectCoinAddress {
    projectCoinAddress: Address;
    this_contract_wallet:Address;
}

// jetton message 
message(0x7362d09c) TokenNotification {
    query_id: Int as uint64;
    amount: Int as coins;
    from: Address;
    forward_payload: Slice as remaining; // Comment Text message when Transfer the jetton 
}

message(0xf8a7ea5) TokenTransfer {
    query_id: Int as uint64;
    amount: Int as coins;
    destination: Address;
    response_destination: Address?;
    custom_payload: Cell?;
    forward_ton_amount: Int as coins;
    forward_payload: Slice as remaining; // Comment Text message when Transfer the jetton
}

message Bounced {
    queryId: Int as uint64;
    body: Slice as remaining;
}

