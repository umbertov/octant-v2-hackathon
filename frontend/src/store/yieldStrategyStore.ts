import { create } from 'zustand';

interface YieldStrategyState {
    shares: number;
    usdcBalance: number;
    setShares: (shares: number) => void;
    setUsdcBalance: (balance: number) => void;
}

const useYieldStrategyStore = create<YieldStrategyState>((set: (partial: Partial<YieldStrategyState>) => void) => ({
    shares: 0,
    usdcBalance: 0,
    setShares: (shares: number) => set({ shares }),
    setUsdcBalance: (balance: number) => set({ usdcBalance: balance }),
}));

export default useYieldStrategyStore;