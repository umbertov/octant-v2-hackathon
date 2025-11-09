import { useAccount, useSimulateContract, useWriteContract, useReadContract } from 'wagmi'
import { useEffect } from 'react';
import useYieldStrategyStore from '../store/yieldStrategyStore';
import { Button } from '../components/ui/button';
import abi from '../abis/YieldDonatingTokenizedStrategy.json';
import { config } from '@/lib/config';

const contractAddress = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";
const USDC_ADDRESS = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';

const YieldStrategy: React.FC = () => {
    const { shares, usdcBalance, setShares, setUsdcBalance } = useYieldStrategyStore();
    const { address } = useAccount();

    const { data: fetchedShares } = useReadContract({
        address: contractAddress,
        abi,
        functionName: 'balanceOf',
        args: [address],
    });

    const { data: fetchedUsdcBalance } = useReadContract({
        address: USDC_ADDRESS,
        abi,
        functionName: 'balanceOf',
        args: [address],
    });

    const { data: depositSimulation } = useSimulateContract({
        address: contractAddress,
        abi,
        functionName: 'deposit',
        args: [/* amount */],
        config
    });

    const { writeContract } = useWriteContract()

    const { data: withdrawSimulation } = useSimulateContract({
        address: contractAddress,
        abi,
        functionName: 'withdraw',
        args: [/* amount */],
    });

    useEffect(() => {
        if (fetchedShares) setShares(Number(fetchedShares));
        if (fetchedUsdcBalance) setUsdcBalance(Number(fetchedUsdcBalance));
    }, [fetchedShares, fetchedUsdcBalance, setShares, setUsdcBalance]);

    return (
        <div className="p-4">
            <h1 className="text-2xl font-bold mb-4">Yield Donating Strategy</h1>

            <div className="mb-4">
                <p className="text-lg">Current Shares: <span className="font-mono">{shares}</span></p>
                <p className="text-lg">USDC Balance: <span className="font-mono">{usdcBalance}</span></p>
            </div>

            <div className="flex space-x-4">
                <Button
                    disabled={!Boolean(depositSimulation?.request)}
                    onClick={() => writeContract(depositSimulation!.request)}>
                    Deposit
                </Button>
                <Button
                    disabled={!Boolean(withdrawSimulation?.request)}
                    onClick={() => writeContract(withdrawSimulation!.request)}>
                    Withdraw
                </Button>
            </div>
        </div >
    );
};

export default YieldStrategy;