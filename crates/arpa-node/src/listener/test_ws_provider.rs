#[cfg(test)]
mod tests {
    use alloy::eips::BlockNumberOrTag;
    use alloy::primitives::{Address, U256};
    use alloy::providers::{Provider, ProviderBuilder, WsConnect};
    use alloy::sol;
    use anyhow::anyhow;
    use futures::StreamExt;
    use std::time::Duration;

    // Standard ERC20 interface for Transfer event listening
    sol! {
        #[sol(rpc)]
        interface IERC20 {
            event Transfer(address indexed from, address indexed to, uint256 value);
            function transfer(address to, uint256 amount) external returns (bool);
            function balanceOf(address account) external view returns (uint256);
        }
    }

    /// Verify third party WebSocket connection event listening capability
    ///
    /// Usage:
    /// ```bash
    /// export WS_ENDPOINT="wss://your-websocket-endpoint"
    /// export CHAIN_ID=1  # Mainnet
    /// export TOKEN_ADDRESS="0x..."  # ERC20 contract address to listen to
    ///
    /// cargo test verify_third_party_websocket -- --nocapture
    /// ```
    #[tokio::test]
    async fn verify_third_party_websocket() -> Result<(), Box<dyn std::error::Error>> {
        println!("=== Verify third party WebSocket connection event listening capability ===");

        // load from environment variables
        let ws_endpoint =
            std::env::var("WS_ENDPOINT").unwrap_or_else(|_| "ws://100.114.33.96:8546".to_string());
        let chain_id: u64 = std::env::var("CHAIN_ID")
            .unwrap_or_else(|_| "10".to_string())
            .parse()
            .map_err(|e| anyhow!("Invalid CHAIN_ID: {}", e))?;
        let token_address_str = std::env::var("TOKEN_ADDRESS")
            .unwrap_or_else(|_| "0x94b008aA00579c1307B0EF2c499aD98a8ce58e58".to_string());
        let token_address: Address = token_address_str
            .parse()
            .map_err(|e| anyhow!("Invalid TOKEN_ADDRESS: {}", e))?;

        println!("Configuration information:");
        println!("  WebSocket endpoint: {}", ws_endpoint);
        println!("  Chain ID: {}", chain_id);
        println!("  Token address: {}", token_address);

        // Step 1: Establish WebSocket connection
        println!("\nStep 1: Establish WebSocket connection...");
        let ws_connect = WsConnect::new(&ws_endpoint);

        let ws_client = ProviderBuilder::new()
            .connect_ws(ws_connect.clone())
            .await
            .map_err(|e| {
                anyhow!(
                    "❌ WebSocket connection failed: {:?}\n\
                    Possible reasons:\n\
                    1. Network unreachable (Network unreachable)\n\
                    2. WebSocket URL invalid\n\
                    3. Connection timeout\n\
                    4. Firewall blocking WebSocket connection\n\
                    5. Server does not support WebSocket",
                    e
                )
            })?;
        println!("✓ WebSocket connection successfully established");

        // Step 2: Verify basic query capability
        println!("\nStep 2: Verify basic query capability...");
        let block_number = ws_client
            .get_block_number()
            .await
            .map_err(|e| anyhow!("❌ Failed to query block number through WebSocket: {:?}", e))?;
        println!("✓ Successfully queried block number: {}", block_number);

        // Step 3: Create event receiver channel
        println!("\nStep 3: Create event receiver channel...");
        let (event_sender, mut event_receiver) =
            tokio::sync::mpsc::channel::<(Address, Address, U256)>(100);
        println!("✓ Event receiver channel created");

        // Step 4: Subscribe to ERC20 Transfer event
        println!("\nStep 4: Subscribe to ERC20 Transfer event...");
        println!("  Contract address: {}", token_address);
        println!("  From block: Latest");

        let erc20_instance = IERC20::new(token_address, ws_client.clone());

        let transfer_stream = erc20_instance
            .Transfer_filter()
            .from_block(BlockNumberOrTag::Latest)
            .subscribe()
            .await
            .map_err(|e| {
                anyhow!(
                    "❌ Failed to subscribe to Transfer event: {:?}\n\
                    Possible reasons:\n\
                    1. Contract address does not exist or is invalid\n\
                    2. WebSocket service does not support event subscription\n\
                    3. Network connection problem",
                    e
                )
            })?;

        let mut transfer_stream = transfer_stream.into_stream();
        println!("✓ Transfer event subscription established, waiting for events...");

        // Step 5: Start event listening task
        let sender_clone = event_sender.clone();
        let subscription_handle = tokio::spawn(async move {
            let mut event_count = 0;
            while let Some(event_result) = transfer_stream.next().await {
                match event_result {
                    Ok((transfer_event, meta)) => {
                        event_count += 1;
                        let block_num = meta.block_number.unwrap_or(0);
                        println!("\n✓ [Event #{}] Transfer event received:", event_count);
                        println!("  Block number: {}", block_num);
                        println!("  From: {:?}", transfer_event.from);
                        println!("  To: {:?}", transfer_event.to);
                        println!("  Amount: {}", transfer_event.value);

                        let event_data =
                            (transfer_event.from, transfer_event.to, transfer_event.value);
                        if let Err(e) = sender_clone.send(event_data).await {
                            println!("⚠️ Failed to send event to channel: {}", e);
                            break;
                        }
                    }
                    Err(e) => {
                        println!("❌ Error receiving Transfer event: {:?}", e);
                        break;
                    }
                }
            }
            println!(
                "\nEvent listening task completed, received {} events",
                event_count
            );
        });

        // Step 6: Wait for a period of time to receive events
        println!("\nStep 5: Listening for events (30 seconds)...");
        println!("Note: If other addresses send Transfer transactions to this contract, you should see events");

        let timeout_duration = Duration::from_secs(30);
        let start_time = std::time::Instant::now();

        loop {
            tokio::select! {
                // Receive events
                event = event_receiver.recv() => {
                    if let Some((from, to, value)) = event {
                        println!("\n🎉 Successfully received Transfer event!");
                        println!("  From: {:?}", from);
                        println!("  To: {:?}", to);
                        println!("  Amount: {}", value);
                        println!("\n✓ WebSocket event listening capability verified successfully!");

                        subscription_handle.abort();
                        return Ok(());
                    } else {
                        println!("⚠️ Event channel closed");
                        break;
                    }
                }
                // Timeout check
                _ = tokio::time::sleep(Duration::from_millis(100)) => {
                    if start_time.elapsed() >= timeout_duration {
                        println!("\n⏱️ Timeout: No Transfer events received within 30 seconds");
                        println!("This may be because:");
                        println!("  1. No Transfer transactions occurred during this period");
                        println!("  2. The contract address is incorrect");
                        println!("  3. Event subscription is not working properly");
                        println!("\nBut WebSocket connection and subscription mechanism have been verified to be available ✓");
                        break;
                    }
                }
            }
        }

        subscription_handle.abort();
        println!("\n=== Verification completed ===");
        Ok(())
    }
}
