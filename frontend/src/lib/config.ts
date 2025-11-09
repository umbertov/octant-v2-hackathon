import { mainnet } from 'wagmi/chains'
import { getDefaultConfig } from '@rainbow-me/rainbowkit';

import { defineChain } from 'viem'

export const devnet = defineChain({
    id: 8,
    name: 'Octant Devnet',
    nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
    rpcUrls: {
        default: { http: ['https://dashboard.tenderly.co/explorer/vnet/82c86106-662e-4d7f-a974-c311987358ff'] },
    },
    blockExplorers: {
        default: { name: 'Etherscan', url: 'https://etherscan.io' },
    },
    contracts: {
        ensRegistry: {
            address: '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e',
        },
        ensUniversalResolver: {
            address: '0xE4Acdd618deED4e6d2f03b9bf62dc6118FC9A4da',
            blockCreated: 16773775,
        },
        multicall3: {
            address: '0xca11bde05977b3631167028862be2a173976ca11',
            blockCreated: 14353601,
        },
    },
})



export const config = getDefaultConfig({
    appName: 'My RainbowKit App',
    projectId: 'YOUR_PROJECT_ID',
    chains: [mainnet, devnet],
    ssr: false, // If your dApp uses server side rendering (SSR)
});