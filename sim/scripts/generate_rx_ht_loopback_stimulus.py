#!/usr/bin/env python3
"""Generate RX loopback stimulus from TX joint core IQ CSV.

This reproduces the bridge used for the HT MCS0-7 source-fix sweep:

- read `tx_main_joint_core_iq.csv` from TX joint simulation
- apply the validated HT-SIG bridge fix by negating HT-SIG data subcarriers
  in the frequency domain while leaving pilot subcarriers unchanged
- add 100 zero samples before and 200 zero samples after the packet
- write the RX sample file as `i q 0` text rows
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

import numpy as np


PILOT_SUBCARRIERS = {-21, -7, 7, 21}
DATA_SUBCARRIERS = [
    k
    for k in list(range(-26, 0)) + list(range(1, 27))
    if k not in PILOT_SUBCARRIERS
]


def read_core_iq(path: Path) -> list[complex]:
    samples: list[complex] = []
    with path.open(newline="") as fh:
        for row in csv.DictReader(fh):
            samples.append(complex(int(row["i"]), int(row["q"])))
    return samples


def apply_ht_sig_data_bin_fix(samples: list[complex]) -> list[complex]:
    fixed = list(samples)

    # In the TX core stream the two HT-SIG OFDM symbols start at samples 400
    # and 480. Each symbol is 16-sample CP + 64-sample useful FFT window.
    for sym_start in (400, 480):
        useful = np.array(fixed[sym_start + 16 : sym_start + 80], dtype=np.complex128)
        freq = np.fft.fft(useful)
        for subcarrier in DATA_SUBCARRIERS:
            freq[subcarrier % 64] *= -1
        corrected = np.fft.ifft(freq)
        full_symbol = np.concatenate([corrected[-16:], corrected])
        for offset, value in enumerate(full_symbol):
            fixed[sym_start + offset] = complex(
                int(np.rint(value.real)), int(np.rint(value.imag))
            )

    return fixed


def write_rx_stimulus(path: Path, samples: list[complex], pre_zeros: int, post_zeros: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as fh:
        for _ in range(pre_zeros):
            fh.write("0 0 0\n")
        for sample in samples:
            fh.write(f"{int(sample.real)} {int(sample.imag)} 0\n")
        for _ in range(post_zeros):
            fh.write("0 0 0\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tx-core-iq", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--pre-zeros", default=100, type=int)
    parser.add_argument("--post-zeros", default=200, type=int)
    args = parser.parse_args()

    samples = read_core_iq(args.tx_core_iq)
    fixed = apply_ht_sig_data_bin_fix(samples)
    write_rx_stimulus(args.out, fixed, args.pre_zeros, args.post_zeros)
    print(f"WROTE {args.out} samples={len(fixed) + args.pre_zeros + args.post_zeros}")


if __name__ == "__main__":
    main()
