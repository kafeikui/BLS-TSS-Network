#[cfg(test)]
mod tests {
    use alloy::eips::BlockNumberOrTag;
    use alloy::primitives::Address;
    use alloy::providers::{Provider, WsConnect};
    use alloy::signers::local::PrivateKeySigner;
    use alloy::sol;
    use anyhow::anyhow;
    use arpa_core::build_websocket_client;

    // NodeRegistry contract interface for AssetAccountSet event
    sol! {
        #[sol(rpc)]
        interface INodeRegistry {
            event AssetAccountSet(address indexed assetAccountAddress, address indexed nodeAddress);
        }
    }

    /// 查询历史 AssetAccountSet 事件
    ///
    /// 使用方法：
    /// ```bash
    /// # 设置环境变量
    /// export WS_ENDPOINT="wss://your-websocket-endpoint"
    /// export CHAIN_ID=1  # 链 ID
    /// export NODE_REGISTRY_ADDRESS="0x..."  # NodeRegistry 合约地址
    /// export NODE_ADDRESS="0x..."  # 要筛选的 nodeAddress
    /// export FROM_BLOCK=1000000  # 起始区块号（可选，默认从合约部署区块开始）
    /// export TO_BLOCK=2000000  # 结束区块号（可选，默认到最新区块）
    ///
    /// # 运行测试
    /// cargo test test_query_historical_asset_account_set_events -- --nocapture
    /// ```
    #[tokio::test]
    async fn test_query_historical_asset_account_set_events(
    ) -> Result<(), Box<dyn std::error::Error>> {
        println!("=== 开始查询历史 AssetAccountSet 事件 ===");

        // 从环境变量获取配置
        let ws_endpoint = std::env::var("WS_ENDPOINT").unwrap_or_else(|_| {
            "wss://ethereum-mainnet.core.chainstack.com/dfe7d5929bc5d9e0b436f6df4337908f"
                .to_string()
        });
        let chain_id: u64 = std::env::var("CHAIN_ID")
            .unwrap_or_else(|_| "1".to_string())
            .parse()
            .map_err(|e| anyhow!("Invalid CHAIN_ID: {}", e))?;
        let node_registry_address_str = std::env::var("NODE_REGISTRY_ADDRESS")
            .unwrap_or_else(|_| "0x58e39879374901e17A790af039DC9Ac06baCf25B".to_string());
        let node_registry_address: Address = node_registry_address_str
            .parse()
            .map_err(|e| anyhow!("Invalid NODE_REGISTRY_ADDRESS: {}", e))?;
        let node_address_str = std::env::var("NODE_ADDRESS")
            .unwrap_or_else(|_| "0x4Bd479A34450d0cB1f5ef16a877Bee47E1e4cDb9".to_string());
        let node_address: Address = node_address_str
            .parse()
            .map_err(|e| anyhow!("Invalid NODE_ADDRESS: {}", e))?;

        // 获取区块范围
        let from_block = std::env::var("FROM_BLOCK")
            .ok()
            .and_then(|s| s.parse::<u64>().ok())
            .map(BlockNumberOrTag::Number);
        let to_block = std::env::var("TO_BLOCK")
            .ok()
            .and_then(|s| s.parse::<u64>().ok())
            .map(BlockNumberOrTag::Number);

        println!("配置信息:");
        println!("  WebSocket 端点: {}", ws_endpoint);
        println!("  链 ID: {}", chain_id);
        println!("  NodeRegistry 合约地址: {}", node_registry_address);
        println!("  要筛选的 nodeAddress: {}", node_address);
        if let Some(ref fb) = from_block {
            println!("  起始区块: {:?}", fb);
        } else {
            println!("  起始区块: 合约部署区块");
        }
        if let Some(ref tb) = to_block {
            println!("  结束区块: {:?}", tb);
        } else {
            println!("  结束区块: Latest");
        }

        // Step 1: 建立 WebSocket 连接
        println!("\n步骤 1: 建立 WebSocket 连接...");
        let ws_connect = WsConnect::new(&ws_endpoint);
        let test_wallet = PrivateKeySigner::random();

        let ws_client = build_websocket_client(test_wallet.clone(), chain_id, ws_connect.clone())
            .await
            .map_err(|e| {
                anyhow!(
                    "❌ WebSocket 连接失败: {:?}\n\
                    可能的原因:\n\
                    1. 网络不可达\n\
                    2. WebSocket URL 无效\n\
                    3. 连接超时",
                    e
                )
            })?;
        println!("✓ WebSocket 连接成功建立");

        // Step 2: 获取当前区块号
        println!("\n步骤 2: 获取当前区块号...");
        let current_block = ws_client
            .get_block_number()
            .await
            .map_err(|e| anyhow!("❌ 无法通过 WebSocket 查询区块号: {:?}", e))?;
        println!("✓ 当前区块号: {}", current_block);

        // Step 3: 获取合约部署区块号
        println!("\n步骤 3: 获取合约部署区块号...");
        // let deployment_block = if let Some(fb) = from_block {
        //     match fb {
        //         BlockNumberOrTag::Number(n) => n,
        //         _ => {
        //             // 尝试通过查询合约的第一个交易来获取部署区块
        //             // 如果无法获取，使用 Earliest
        //             println!("  尝试查找合约部署区块...");
        //             // 这里可以添加逻辑来查找合约部署区块
        //             // 暂时使用 Earliest 或环境变量
        //             std::env::var("DEPLOYMENT_BLOCK")
        //                 .ok()
        //                 .and_then(|s| s.parse::<u64>().ok())
        //                 .unwrap_or(0)
        //         }
        //     }
        // } else {
        //     // 从环境变量获取部署区块，如果没有则使用 Earliest
        //     std::env::var("DEPLOYMENT_BLOCK")
        //         .ok()
        //         .and_then(|s| s.parse::<u64>().ok())
        //         .unwrap_or(0)
        // };

        let deployment_block = 19614426;
        println!("✓ 合约部署区块: {}", deployment_block);

        // Step 4: 计算查询范围并分块查询
        println!("\n步骤 4: 分块查询历史 AssetAccountSet 事件...");
        println!("  合约地址: {}", node_registry_address);
        println!("  筛选条件: nodeAddress = {}", node_address);
        println!("  查询范围: {} -> {}", deployment_block, current_block);
        println!("  步长: 10000 个区块");

        let node_registry_instance = INodeRegistry::new(node_registry_address, ws_client.clone());
        const BLOCK_STEP: u64 = 10000; // RPC provider 限制，每次查询 10000 个区块

        let mut start_block = deployment_block;
        let mut chunk_count = 0;

        // 分块查询，找到匹配的日志后立即返回
        while start_block <= current_block {
            chunk_count += 1;
            let end_block = std::cmp::min(start_block + BLOCK_STEP - 1, current_block);

            println!(
                "\n  查询区块范围 [{}, {}] (块 #{})...",
                start_block, end_block, chunk_count
            );

            // 构建事件过滤器
            let mut filter = node_registry_instance.AssetAccountSet_filter();
            filter = filter.topic2(node_address);
            filter = filter.from_block(BlockNumberOrTag::Number(start_block));
            filter = filter.to_block(BlockNumberOrTag::Number(end_block));

            // 查询当前区块范围的日志
            match filter.query().await {
                Ok(logs) => {
                    println!("    ✓ 找到 {} 条日志", logs.len());
                    for (event, meta) in logs {
                        let block_num = meta.block_number.unwrap_or(0);
                        let tx_hash = meta.transaction_hash.unwrap_or_default();

                        // 验证 nodeAddress 是否匹配
                        if event.nodeAddress == node_address {
                            println!("\n🎉 找到匹配的 AssetAccountSet 事件!");
                            println!("  交易哈希: {:?}", tx_hash);
                            println!("  区块号: {}", block_num);
                            println!("  assetAccountAddress: {:?}", event.assetAccountAddress);
                            println!("  nodeAddress: {:?}", event.nodeAddress);
                            println!("\n✓ 查询完成，共查询 {} 个区块范围", chunk_count);

                            // 找到匹配的日志后立即返回
                            return Ok(());
                        }
                    }
                }
                Err(e) => {
                    println!("    ⚠️ 查询失败: {:?}", e);
                    println!("    继续查询下一个区块范围...");
                }
            }

            // 移动到下一个区块范围
            start_block = end_block + 1;

            // 添加短暂延迟，避免 RPC 限流
            tokio::time::sleep(std::time::Duration::from_millis(100)).await;
        }

        println!("\n✓ 分块查询完成，共查询 {} 个区块范围", chunk_count);
        println!("⚠️ 未找到匹配的日志");

        // Step 5: 输出结果摘要（如果没有找到匹配的日志）
        println!("\n=== 查询结果摘要 ===");
        println!(
            "⚠️ 未找到包含 AssetAccountSet 事件且 nodeAddress = {} 的交易",
            node_address
        );
        println!("这可能是因为:");
        println!("  1. 指定的区块范围内没有匹配的事件");
        println!("  2. nodeAddress 不正确");
        println!("  3. 合约地址不正确");

        println!("\n=== 查询完成 ===");
        Ok(())
    }
}
