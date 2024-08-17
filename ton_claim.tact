import "@stdlib/deploy";
import "./message.tact";

/**
    Used to claim project tokens purchased in the IDO contract on EVM in the claim contract
    based on the whitelist signed claim amount and claim address eligibility.
*/
contract TonClaim with Deployable {
    // Empty init() function is present by default in all Tact contracts
    // since v1.3.0, so the following may be omitted:
    
    // Contract owner address
    owner: Address;

    // Wallet address of the investment token and project token, token address, decimals, etc.
    this_contract_projectCoinWallet: Address?;

    project_coin_address: Address;

    // max claims limit
    // The max limit will be determined based on the actual number of users participating in 
    // the IDO, and it will not grow indefinitely. It depends on the IDO allocation and the 
    // number of stakers.
    const MAX_CLAIMS: Int = 5000; 
    // User claim records
    index: Int as uint32 = 0;    
    claim_record: map<Address, ClaimRecord>;
    claim_list: map<Int, ClaimRecord>;
    pending_claims: map<Int, Address>;

    // Project token balance
    // contract_balance: Int as coins = 0;

    // Total amount of tokens claimed so far
    ido_claim_amount: Int as coins = 0;

    // Start time for claiming tokens
    claim_time: Int as uint32 = 1720935200;

    // Project end time
    end_time: Int as uint32 = 1720945200;
    
    // Public key used to verify signatures
    publicKey: Int = 11515758040791894312519273808582344479606047423343319073911177921016049419084;  


    // Initialize contract
    init(projectCoinAddress: Address) {
        
        self.owner =  sender();        

        self.project_coin_address = projectCoinAddress;
        self.this_contract_projectCoinWallet = null; // delay set

    }

    // Internal functions ***********************************/
    
    // Verify the signature of the token claim message parameters
    fun verifySignature(timestamp: Int, claimAmount: Int, claimAddress: Address, signature: Slice): Bool {
        let dataToSign = beginCell()
            .storeUint(timestamp, 32)
            .storeAddress(claimAddress)
            .storeCoins(claimAmount)
            .endCell();
        return checkSignature(dataToSign.hash(), signature, self.publicKey);
    }

    // Event handling functions ***********************************/

    // set project coin address 
    receive(msg: SetProjectCoinAddress){
        let ctx: Context = context();
        require(ctx.sender==self.owner,"Only Owner can set this parameter!");

        require(now() < self.claim_time, "set projectcoinaddress and jetton wallet is not allowed after claim time");
        self.project_coin_address = msg.projectCoinAddress;
        self.this_contract_projectCoinWallet = msg.this_contract_wallet;
    }

    // // Set public key for verifying signatures
    // receive(msg: SetPublicKey) {
    //     require(sender() == self.owner, "Only owner can set public key");
    //     self.publicKey = msg.publicKey;
    // }

    // // Set claim time nodes, the same as in the IDO project
    // receive(msg: SetIDOTimes) {
    //     require(sender() == self.owner, "Only owner can set times");
    //     self.claim_time = msg.claimTime;
    //     self.end_time = msg.endTime;
    // }

    // Token transfer notification message processing
    receive(ido: TokenNotification) {
        // do nothing

        // require(sender() == self.this_contract_projectCoinWallet, "Invalid sender");
        // // Update contract balance
        // self.contract_balance += ido.amount;
    }

    // Handle user token claim request
    receive(msg: Claim) {

        // Ensure enough gas is provided
        require(context().value >= ton("0.2"), "Not enough value provided for gas");
        // Ensure the maximum number of claims is not exceeded
        require(self.index < self.MAX_CLAIMS, "Maximum number of claims reached");
        // Ensure call time is after claim time
        require(now() >= self.claim_time, "Claiming is not allowed before claim time");
        require(now() < self.end_time, "Claiming is not allowed After end time");

        let claimAmount: Int = msg.claimAmount;
        let timestamp: Int = msg.timestamp;
        let signature: Slice = msg.signature;

        require(self.verifySignature(timestamp, claimAmount, sender(), signature), "Invalid received signature");
        dump(claimAmount);

        // Check if the contract balance is sufficient
        // require(self.contract_balance >= claimAmount, "Insufficient contract balance");

        // Get the claim record of the caller sender
        let sender: Address = sender();
        let userRecord: ClaimRecord? = self.claim_record.get(sender);
        // Ensure the user has not claimed before, record is empty
        require(userRecord == null, "Have claim record found for this address");

        // 使用当前时间戳作为 queryId
        let queryId: Int = now();  
        // 记录正在进行的交易
        self.pending_claims.set(queryId, sender());

        // Execute token transfer
        send(SendParameters{
            to: self.this_contract_projectCoinWallet!!,
            value: ton("0.1"),
            mode: SendRemainingValue,
            body: TokenTransfer{
                query_id: queryId,
                amount: claimAmount,
                destination: sender,
                response_destination: sender,
                custom_payload: null,
                forward_ton_amount: 0,
                forward_payload: beginCell().storeUint(0, 1).endCell().beginParse()
            }.toCell()
        });

        // Update user record
        self.claim_record.set(sender,
            ClaimRecord{
                claimedUserAddress: sender,
                claimedAmount: claimAmount,
                claimedAt: now()
            }    
        );
        self.claim_list.set(self.index, self.claim_record.get(sender)!!);
        self.index += 1;
        
        // Update contract balance
        // self.contract_balance -= claimAmount;
        // Update total claimed amount
        self.ido_claim_amount += claimAmount;

        // Emit event
        emit(TransferEvent{
            sender_address: sender,
            jetton_amount: claimAmount,
            ido_action: "claim",
            action_message: "success",
            idoTimestamp: now()
        }.toCell());

    }

    // handle other bounced
    bounced(rawMsg: Slice) {
        // ...
    }

    // handle tokentransfer bonced msg
    bounced(msg: bounced<TokenTransfer>) {
        // Due to the 224-bit limit,get queryId from the original message
        let queryId: Int = msg.query_id;

        // Retrieve the original sender address
        let originalSender: Address = self.pending_claims.get(queryId)!!;

        // retrieve amount from claim_record
        let amount: Int = self.claim_record.get(originalSender)!!.claimedAmount;

        // Restore the state
        // self.contract_balance += amount;
        self.ido_claim_amount -= amount;

        // Remove the user's claim record and pending claim
        self.claim_record.set(originalSender, null);
        self.pending_claims.set(queryId, null);

        // Emit an event notification
        emit(BalanceCorrectionEvent{
            claim_address: originalSender,
            jetton_amount: amount,
            action: "claim_bounced",
            timestamp: now()
        }.toCell());
    }
        
    // Handle admin request to adjust contract balance and correct user claim records
    // If in a very rare case, the user's claim transfer fails, the admin needs to manually correct the user claim record and adjust the contract balance
    // receive(msg: AdminCorrectRecord) {
    //     require(sender() == self.owner, "Only owner can correct balance");
        
    //     self.contract_balance += msg.userAmount;
    //     self.ido_claim_amount -= msg.userAmount;

    //     // Update user record to null
    //     self.claim_record.set(msg.userClaimAddress, null);

    //     emit(BalanceCorrectionEvent{
    //         claim_address: msg.userClaimAddress,
    //         jetton_amount: msg.userAmount,
    //         action: "corrected",
    //         timestamp: now()
    //     }.toCell());
    // }

    // Handle request to withdraw remaining project tokens (if any) to the project wallet after the IDO ends
    receive(msg: WithdrawFunds) {
        // Ensure enough gas is provided
        require(context().value >= ton("0.2"), "Not enough value provided for gas");
        // Check if the caller is the owner
        require(sender() == self.owner, "Only owner can withdraw funds");

        // // Check if the IDO has successfully ended
        require(now() >= self.end_time, "IDO has not ended yet");
        
        // Withdraw all project tokens held by the contract
        let amount_to_send: Int = msg.amount; //self.contract_balance;
        // Update contract balance
        // self.contract_balance = 0;

        // Send project tokens to the specified project wallet
        send(SendParameters{
            to: self.this_contract_projectCoinWallet!!,
            value: ton("0.1"),
            mode: (SendRemainingValue + SendIgnoreErrors),
            body: TokenTransfer{
                query_id: 0,
                amount: amount_to_send,
                destination: msg.destination,
                response_destination: sender(),
                custom_payload: null,
                forward_ton_amount: 0,
                forward_payload: beginCell().storeUint(0, 1).endCell().beginParse()
            }.toCell()
        });

        // Emit withdrawal event
        emit(TransferEvent{
            sender_address: myAddress(),
            jetton_amount: amount_to_send,
            ido_action: "withdraw_coins",
            action_message: "Project coins withdrawn by owner",
            idoTimestamp: now()
        }.toCell());
    } 

    // Contract internal state retrieval functions ***********************************/

    // Get project token address
    get fun projectCoin(): Address {
        return self.project_coin_address;
    }

    // Get the total claimed amount so far
    get fun claimAmount(): Int {
        return self.ido_claim_amount;
    }
    // Get the current contract signature public key
    get fun publickey(): Int {
        return self.publicKey;
    }
    // Get the project token balance held by the contract, can also be retrieved externally.
    // get fun getContractBalance(): Int {
    //     return self.contract_balance;
    // }
    // Get user's claim information
    get fun userClaimInfo(userAddress: Address): ClaimRecord {
        let userRecord: ClaimRecord? = self.claim_record.get(userAddress);
        if (userRecord != null) {
            return userRecord!!;
        }
        return ClaimRecord{
            claimedUserAddress: userAddress,
            claimedAmount: 0,
            claimedAt: 0
        };
    }
    // Overall parameter retrieval
    // Get the overall information of the claim contract, including parameters and state
    get fun claimInfo(): ClaimInfoGet {
        return ClaimInfoGet{
            contractOwner: self.owner,
            claimUserCount: self.index,
            // contractBalance: self.contract_balance,
            publicKey: self.publicKey,
            projectCoinAddress: self.project_coin_address,
            endTime: self.end_time,
            claimTime: self.claim_time,
            claimedAmount: self.ido_claim_amount,
        };
    }
}
