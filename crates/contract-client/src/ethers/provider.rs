use crate::{
    error::{ContractClientError, ContractClientResult},
    provider::BlockFetcher,
};
use alloy::providers::Provider;
use arpa_core::{ProviderClientWithSigner, DEFAULT_PROVIDER_EVENT_POLLING_INTERVAL_MILLIS};
use async_trait::async_trait;
use futures_util::StreamExt;
use std::{future::Future, time::Duration};

#[async_trait]
impl BlockFetcher for ProviderClientWithSigner {
    async fn watch_new_block_height<
        C: FnMut(usize) -> F + Send,
        F: Future<Output = ContractClientResult<()>> + Send,
    >(
        &self,
        mut cb: C,
    ) -> ContractClientResult<()> {
        let mut watcher = self.watch_full_blocks().await?;

        watcher.set_poll_interval(Duration::from_millis(
            DEFAULT_PROVIDER_EVENT_POLLING_INTERVAL_MILLIS,
        ));

        let mut stream = watcher.into_stream();

        while let Some(Ok(block)) = stream.next().await {
            cb(block.header.number as usize).await?;
        }
        Err(ContractClientError::FetchingBlockError)
    }

    async fn subscribe_new_block_height<
        C: FnMut(usize) -> F + Send,
        F: Future<Output = ContractClientResult<()>> + Send,
    >(
        &self,
        mut cb: C,
    ) -> ContractClientResult<()> {
        let mut stream = self.subscribe_blocks().await?.into_stream();

        while let Some(block) = stream.next().await {
            cb(block.number as usize).await?;
        }
        Err(ContractClientError::FetchingBlockError)
    }
}
