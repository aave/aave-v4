#!/usr/bin/env python3
"""
Fee Griefing Analysis Script

This script analyzes when treasury fees round to zero due to small accruals.
It models the exact Solidity math from Aave v4 to find the boundary conditions
where griefing is possible (fees round to 0 for treasury).

Key equations modeled:
1. Linear interest: result = RAY + (rate * elapsed / SECONDS_PER_YEAR)
2. Index growth: newIndex = previousIndex * linearInterest / RAY (rayMulUp)
3. Aggregated owed (ray): drawnShares * drawnIndex (for simplicity, ignoring premium)
4. Interest accrued: aggregatedOwedAfter - aggregatedOwedBefore 
5. Fee amount: interest * liquidityFee / PERCENTAGE_FACTOR (percentMulDown)
6. Fee shares: feeAmount * (totalShares + VIRTUAL_SHARES) / (totalAssets - feeAmount + VIRTUAL_ASSETS) (floor)

For fee shares to round to 0:
  feeAmount * (totalShares + VIRTUAL_SHARES) < (totalAssets - feeAmount + VIRTUAL_ASSETS)
"""

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm
import matplotlib.ticker as ticker

# Constants from Solidity
RAY = 10**27
PERCENTAGE_FACTOR = 10**4  # 100.00% = 10000 BPS
SECONDS_PER_YEAR = 365 * 24 * 60 * 60  # 31536000
VIRTUAL_ASSETS = 10**6
VIRTUAL_SHARES = 10**6
MAX_SUPPLY_AMOUNT = 10**30  # 1e30 in tests
BLOCK_TIME = 12  # seconds (Ethereum)


def calculate_linear_interest(rate: int, elapsed: int) -> int:
    return RAY + (rate * elapsed) // SECONDS_PER_YEAR


def ray_mul_up(a: int, b: int) -> int:
    product = a * b
    return (product // RAY) + (1 if product % RAY > 0 else 0)


def percent_mul_down(value: int, percentage: int) -> int:
    return (value * percentage) // PERCENTAGE_FACTOR


def from_ray_up(a: int) -> int:
    return (a // RAY) + (1 if a % RAY > 0 else 0)


def to_shares_down(assets: int, total_assets: int, total_shares: int) -> int:
    numerator = assets * (total_shares + VIRTUAL_SHARES)
    denominator = total_assets + VIRTUAL_ASSETS
    return numerator // denominator


def calculate_fee_shares(
    drawn_shares: int,
    previous_index: int,
    drawn_rate: int,
    elapsed: int,
    liquidity_fee: int,
    liquidity: int,
    added_shares: int,
) -> tuple[int, int, int]:
    # Step 1: Calculate new index
    linear_interest = calculate_linear_interest(drawn_rate, elapsed)
    new_index = ray_mul_up(previous_index, linear_interest)
    
    # Step 2: Calculate aggregated owed before and after (simplified - no premium)
    aggregated_owed_ray_before = drawn_shares * previous_index
    aggregated_owed_ray_after = drawn_shares * new_index
    
    # Step 3: Convert to assets (rounding up)
    aggregated_owed_before = from_ray_up(aggregated_owed_ray_before)
    aggregated_owed_after = from_ray_up(aggregated_owed_ray_after)
    
    # Step 4: Interest earned
    interest_earned = aggregated_owed_after - aggregated_owed_before
    
    # Step 5: Fee amount (percentMulDown)
    fee_amount = percent_mul_down(interest_earned, liquidity_fee)
    
    if fee_amount == 0:
        return 0, 0, interest_earned
    
    # Step 6: Calculate total assets for share conversion
    # totalAssets = liquidity + swept + aggregatedOwedAfter - feeAmount
    # For simplicity, assume swept = 0
    total_assets = liquidity + aggregated_owed_after - fee_amount
    
    # Step 7: Convert fee amount to shares
    fee_shares = to_shares_down(fee_amount, total_assets, added_shares)
    
    return fee_shares, fee_amount, interest_earned


def find_min_debt_for_nonzero_fees(
    liquidity_fee: int,
    drawn_rate: int = int(0.10 * RAY),  # 10% APR default
    liquidity: int = 10**18,  # 1 token of liquidity
    added_shares: int = 10**18,  # 1:1 shares to assets initially
) -> int:
    """
    Binary search to find minimum debt where fee shares > 0 for 1 block.
    """
    if liquidity_fee == 0:
        return MAX_SUPPLY_AMOUNT  # Never gets fees at 0%
    
    previous_index = RAY  # Start at 1.0
    elapsed = BLOCK_TIME
    
    low, high = 1, MAX_SUPPLY_AMOUNT
    
    while low < high:
        mid = (low + high) // 2
        fee_shares, _, _ = calculate_fee_shares(
            drawn_shares=mid,
            previous_index=previous_index,
            drawn_rate=drawn_rate,
            elapsed=elapsed,
            liquidity_fee=liquidity_fee,
            liquidity=liquidity,
            added_shares=added_shares,
        )
        if fee_shares > 0:
            high = mid
        else:
            low = mid + 1
    
    return low


def analyze_boundary_exact(
    drawn_rate: int = int(0.10 * RAY),  # 10% APR
) -> None:
    """
    Analyze the exact boundary where fees round to 0.
    
    For 1 block at a given rate:
    - Linear interest = RAY + rate * 12 / SECONDS_PER_YEAR
    - Interest fraction = rate * 12 / SECONDS_PER_YEAR (in ray)
    - Interest on debt = drawnShares * interestFraction (in ray)
    - Fee (assets) = interest * liquidityFee / 10000
    - Fee shares = fee * (shares + 1e6) / (assets + 1e6)
    
    Fee shares = 0 when: fee * (shares + 1e6) < (assets + 1e6)
    """
    print("=" * 70)
    print("FEE GRIEFING ANALYSIS - 1 Block Accrual")
    print("=" * 70)
    print(f"Block time: {BLOCK_TIME} seconds")
    print(f"Drawn rate: {drawn_rate / RAY * 100:.2f}% APR")
    print(f"Virtual assets/shares: {VIRTUAL_ASSETS}")
    print()
    
    # Calculate interest fraction per block
    interest_fraction = (drawn_rate * BLOCK_TIME) // SECONDS_PER_YEAR
    print(f"Interest fraction per block (ray): {interest_fraction}")
    print(f"Interest fraction per block (%): {interest_fraction / RAY * 100:.10f}%")
    print()
    
    # For different liquidity fees, find minimum debt
    print("Minimum debt for non-zero fee shares by liquidity fee:")
    print("-" * 50)
    
    test_fees = [1, 10, 50, 100, 500, 1000, 2500, 5000, 10000]
    for fee_bps in test_fees:
        min_debt = find_min_debt_for_nonzero_fees(
            liquidity_fee=fee_bps,
            drawn_rate=drawn_rate,
        )
        
        fee_shares, fee_amount, interest = calculate_fee_shares(
            drawn_shares=min_debt,
            previous_index=RAY,
            drawn_rate=drawn_rate,
            elapsed=BLOCK_TIME,
            liquidity_fee=fee_bps,
            liquidity=10**18,
            added_shares=10**18,
        )
        
        print(f"  {fee_bps:>5} BPS ({fee_bps/100:>6.2f}%): min debt = {min_debt:>25,.0f} "
              f"(~{min_debt/10**18:.2e} tokens)")
    
    # Show impact on different decimal tokens
    print()
    print("=" * 70)
    print("IMPACT BY TOKEN DECIMALS (at 100 BPS = 1% liquidity fee)")
    print("=" * 70)
    
    min_debt_100bps = find_min_debt_for_nonzero_fees(
        liquidity_fee=100,
        drawn_rate=drawn_rate,
    )
    
    token_examples = [
        ("DAI/ETH (18 dec)", 18),
        ("WBTC (8 dec)", 8),
        ("USDC/USDT (6 dec)", 6),
    ]
    
    print(f"\nMinimum debt for non-zero treasury fees: {min_debt_100bps:,.0f} asset units")
    print()
    print(f"{'Token':<20} {'Decimals':<10} {'Min Debt (tokens)':<25} {'Risk Level'}")
    print("-" * 70)
    
    for name, decimals in token_examples:
        min_tokens = min_debt_100bps / (10 ** decimals)
        if min_tokens < 0.01:
            risk = "✅ LOW - dust amounts"
        elif min_tokens < 100:
            risk = "⚠️  MEDIUM - small positions affected"
        else:
            risk = "❌ HIGH - significant positions affected"
        print(f"{name:<20} {decimals:<10} {min_tokens:<25,.6f} {risk}")


def create_heatmap(
    drawn_rate: int = int(0.10 * RAY),
    filename: str = "fee_griefing_heatmap.png",
) -> None:
    """
    Create a heatmap showing fee shares for different debt and liquidity fee combinations.
    """
    # Liquidity fee range: 0 to 10000 BPS
    fee_bps_values = np.linspace(1, 10000, 100, dtype=int)
    
    # Debt range: 1e6 to 1e30 (log scale)
    debt_values = np.logspace(6, 30, 100)
    
    # Create meshgrid
    FEE, DEBT = np.meshgrid(fee_bps_values, debt_values)
    fee_shares_matrix = np.zeros_like(FEE, dtype=float)
    
    print("Generating heatmap data...")
    for i, debt in enumerate(debt_values):
        for j, fee_bps in enumerate(fee_bps_values):
            fee_shares, _, _ = calculate_fee_shares(
                drawn_shares=int(debt),
                previous_index=RAY,
                drawn_rate=drawn_rate,
                elapsed=BLOCK_TIME,
                liquidity_fee=int(fee_bps),
                liquidity=int(10**18),
                added_shares=int(10**18),
            )
            fee_shares_matrix[i, j] = fee_shares
    
    # Create figure
    fig, ax = plt.subplots(figsize=(14, 10))
    
    # Create the heatmap with binary coloring (0 fees = red, >0 fees = green)
    # Using a mask to show where fees round to zero
    zero_mask = fee_shares_matrix == 0
    
    # Plot: gray where fees > 0, red where fees = 0
    im = ax.pcolormesh(
        FEE, DEBT, zero_mask.astype(float),
        cmap='RdYlGn_r',  # Red = 1 (zero fees), Green = 0 (positive fees)
        shading='auto'
    )
    
    ax.set_yscale('log')
    ax.set_xlabel('Liquidity Fee (BPS)', fontsize=12)
    ax.set_ylabel('Debt (drawn shares)', fontsize=12)
    ax.set_title(
        f'Fee Griefing Vulnerability Map\n'
        f'(1 block, {drawn_rate/RAY*100:.0f}% APR)\n'
        f'Red = Treasury Fees Round to Zero',
        fontsize=14
    )
    
    # Add colorbar
    cbar = plt.colorbar(im, ax=ax, ticks=[0, 1])
    cbar.ax.set_yticklabels(['Fees > 0 ✓', 'Fees = 0 ✗'])
    
    # Add some reference lines for common debt amounts
    for power in [12, 18, 24, 30]:
        ax.axhline(y=10**power, color='white', linestyle='--', alpha=0.3, linewidth=0.5)
        ax.text(500, 10**power * 1.5, f'10^{power}', color='white', fontsize=8, alpha=0.7)
    
    plt.tight_layout()
    plt.savefig(filename, dpi=150, bbox_inches='tight')
    print(f"Saved heatmap to {filename}")
    plt.close()


def create_boundary_plot(
    drawn_rate: int = int(0.10 * RAY),
    filename: str = "fee_griefing_boundary.png",
) -> None:
    """
    Create a plot showing the boundary line between zero and non-zero fees.
    """
    # Find boundary for each liquidity fee value
    fee_bps_values = np.arange(1, 10001, 100)
    min_debts = []
    
    print("Calculating boundary curve...")
    for fee_bps in fee_bps_values:
        min_debt = find_min_debt_for_nonzero_fees(
            liquidity_fee=int(fee_bps),
            drawn_rate=drawn_rate,
        )
        min_debts.append(float(min_debt))
    
    # Convert to numpy arrays
    min_debts = np.array(min_debts)
    
    fig, ax = plt.subplots(figsize=(12, 8))
    
    ax.fill_between(
        fee_bps_values, min_debts, float(MAX_SUPPLY_AMOUNT),
        alpha=0.3, color='green', label='Fees > 0 (Treasury Protected)'
    )
    ax.fill_between(
        fee_bps_values, 1.0, min_debts,
        alpha=0.3, color='red', label='Fees = 0 (Griefing Zone)'
    )
    
    ax.plot(fee_bps_values, min_debts, 'b-', linewidth=2, label='Boundary')
    
    ax.set_yscale('log')
    ax.set_xlabel('Liquidity Fee (BPS)', fontsize=12)
    ax.set_ylabel('Minimum Debt for Non-Zero Fees', fontsize=12)
    ax.set_title(
        f'Fee Griefing Boundary (1 Block, {drawn_rate/RAY*100:.0f}% APR)\n'
        f'Below the line: Treasury fees round to zero',
        fontsize=14
    )
    ax.legend(loc='upper right')
    ax.grid(True, alpha=0.3)
    
    # Format y-axis
    ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x, p: f'{x:.0e}'))
    
    plt.tight_layout()
    plt.savefig(filename, dpi=150, bbox_inches='tight')
    print(f"Saved boundary plot to {filename}")
    plt.close()


def create_rate_comparison_plot(filename: str = "fee_griefing_rate_comparison.png") -> None:
    """
    Create a plot comparing boundaries at different interest rates.
    """
    rates = [
        (int(0.01 * RAY), "1% APR"),
        (int(0.05 * RAY), "5% APR"),
        (int(0.10 * RAY), "10% APR"),
        (int(0.20 * RAY), "20% APR"),
        (int(0.50 * RAY), "50% APR"),
    ]
    
    fee_bps_values = np.arange(1, 10001, 50)  # Finer graining
    
    fig, ax = plt.subplots(figsize=(14, 9))
    
    print("Calculating rate comparison...")
    for rate, label in rates:
        min_debts = []
        for fee_bps in fee_bps_values:
            min_debt = find_min_debt_for_nonzero_fees(
                liquidity_fee=int(fee_bps),
                drawn_rate=rate,
            )
            min_debts.append(float(min_debt))
        min_debts = np.array(min_debts)
        ax.plot(fee_bps_values, min_debts, linewidth=2, label=label)
    
    ax.set_yscale('log')
    ax.set_xlabel('Liquidity Fee (BPS)', fontsize=12)
    ax.set_ylabel('Minimum Debt for Non-Zero Fees (asset units)', fontsize=12)
    ax.set_title(
        'Fee Griefing Boundary at Different Interest Rates (1 Block)\n'
        'Below each line: Treasury fees round to zero',
        fontsize=14
    )
    ax.legend(loc='upper right', fontsize=11)
    ax.grid(True, alpha=0.3)
    ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x, p: f'{x:.0e}'))
    
    plt.tight_layout()
    plt.savefig(filename, dpi=150, bbox_inches='tight')
    print(f"Saved rate comparison to {filename}")
    plt.close()


def create_decimal_comparison_plot(
    filename: str = "fee_griefing_by_decimals.png",
) -> None:
    """
    Create separate plots showing fee griefing thresholds for each token decimal
    configuration across multiple APRs.
    """
    # APRs to compare
    rates = [
        (int(0.01 * RAY), "1% APR"),
        (int(0.02 * RAY), "2% APR"),
        (int(0.04 * RAY), "4% APR"),
        (int(0.05 * RAY), "5% APR"),
        (int(0.07 * RAY), "7% APR"),
        (int(0.10 * RAY), "10% APR"),
    ]
    
    # Each config: (decimals, label, filename, reference_lines, ylim)
    # Reference lines are (value, label) - appropriate for each token type
    # For WBTC: assume $80,000/BTC
    decimals_configs = [
        (6, "USDC/USDT (6 decimals)", "fee_griefing_6dec.png", 
         [(1, "$1"), (10, "$10"), (100, "$100"), (1000, "$1K"), (10000, "$10K"), (100000, "$100K")],
         None),
        (8, "WBTC (8 decimals) - assuming $80K/BTC", "fee_griefing_8dec.png",
         [(0.00125, "$100"), (0.0125, "$1K"), (0.125, "$10K"), (1.25, "$100K"), (12.5, "$1M")],
         (0.001, 100000)),  # Set y-axis limits
        (18, "ETH/DAI (18 decimals)", "fee_griefing_18dec.png",
         [(1e-10, "1e-10"), (1e-8, "1e-8"), (1e-6, "1e-6"), (1e-4, "1e-4"), (1e-2, "0.01"), (1, "1")],
         None),
    ]
    
    fee_bps_values = np.arange(1, 10001, 50)  # Finer graining
    
    # Color map for rates
    colors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd', '#8c564b']
    
    print("Calculating decimal comparison...")
    for decimals, dec_label, out_filename, ref_lines, ylim in decimals_configs:
        fig, ax = plt.subplots(figsize=(12, 8))
        
        for (rate, rate_label), color in zip(rates, colors):
            min_tokens_list = []
            for fee_bps in fee_bps_values:
                min_debt = find_min_debt_for_nonzero_fees(
                    liquidity_fee=int(fee_bps),
                    drawn_rate=rate,
                )
                # Convert to token amounts
                min_tokens = min_debt / (10 ** decimals)
                min_tokens_list.append(float(min_tokens))
            
            min_tokens_arr = np.array(min_tokens_list)
            ax.plot(fee_bps_values, min_tokens_arr, linewidth=2.5, label=rate_label, color=color)
        
        ax.set_yscale('log')
        ax.set_xlabel('Liquidity Fee (BPS)', fontsize=12)
        ax.set_ylabel('Minimum Debt (in tokens)', fontsize=12)
        ax.set_title(
            f'Fee Griefing Threshold - {dec_label} (1 Block)\n'
            f'Below each line: Treasury fees round to zero',
            fontsize=14
        )
        ax.legend(loc='upper right', fontsize=11)
        ax.grid(True, alpha=0.3)
        
        # Set y-axis limits if specified
        if ylim:
            ax.set_ylim(ylim)
        
        # Add reference lines (token-specific) on the right side
        for value, label in ref_lines:
            ax.axhline(y=value, color='gray', linestyle=':', alpha=0.5, linewidth=1)
            # Put label on right edge inside the plot
            ax.text(9800, value, f'  {label}', fontsize=9, color='gray', va='center', ha='left',
                   bbox=dict(boxstyle='round,pad=0.2', facecolor='white', edgecolor='none', alpha=0.8))
        
        # Format y-axis
        ax.yaxis.set_major_formatter(ticker.FuncFormatter(
            lambda x, p: f'{x:,.0f}' if x >= 1 else f'{x:.2e}'
        ))
        
        plt.tight_layout()
        plt.savefig(out_filename, dpi=150, bbox_inches='tight')
        print(f"Saved {dec_label} to {out_filename}")
        plt.close()


if __name__ == "__main__":
    # Run analysis
    analyze_boundary_exact()
    print()
    
    # Create visualizations
    create_heatmap()
    create_boundary_plot()
    create_rate_comparison_plot()
    create_decimal_comparison_plot()
    
    print()
    print("=" * 70)
    print("Analysis complete! Check the generated PNG files.")
    print("=" * 70)
