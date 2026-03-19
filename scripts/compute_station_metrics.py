import argparse
import csv
from collections import Counter
from pathlib import Path


RENT_STATION_COL = "대여 대여소명"
RETURN_STATION_COL = "반납대여소명"
RENT_TIME_COL = "대여일시"
RETURN_TIME_COL = "반납일시"


def parse_args():
    parser = argparse.ArgumentParser(
        description="Compute station imbalance metrics from rental CSV files."
    )
    parser.add_argument(
        "--data-dir",
        required=True,
        help="Directory containing rental CSV files.",
    )
    parser.add_argument(
        "--pattern",
        default="*.csv",
        help="Glob pattern to match CSV files (default: *.csv).",
    )
    return parser.parse_args()


def get_hour(value: str, missing: str):
    if not value or value == missing:
        return None
    if len(value) >= 13:
        try:
            return int(value[11:13])
        except ValueError:
            return None
    if " " in value:
        parts = value.split(" ")
        if len(parts) >= 2 and len(parts[1]) >= 2:
            try:
                return int(parts[1][:2])
            except ValueError:
                return None
    return None


def main():
    args = parse_args()
    data_dir = Path(args.data_dir)
    files = sorted(data_dir.glob(args.pattern))
    if not files:
        raise SystemExit("No CSV files found. Check --data-dir/--pattern.")

    rental_counts = Counter()
    return_counts = Counter()
    rent_hour_counts = Counter()
    return_hour_counts = Counter()

    rent_col = None
    return_col = None
    rent_time_col = None
    return_time_col = None

    missing = chr(92) + "N"

    for file_path in files:
        with file_path.open("r", encoding="cp949", newline="") as fp:
            reader = csv.reader(fp)
            header = next(reader)
            if rent_col is None:
                try:
                    rent_col = header.index(RENT_STATION_COL)
                    return_col = header.index(RETURN_STATION_COL)
                    rent_time_col = header.index(RENT_TIME_COL)
                    return_time_col = header.index(RETURN_TIME_COL)
                except ValueError as exc:
                    raise SystemExit(f"Missing expected column: {exc}")

            for row in reader:
                if len(row) <= max(rent_col, return_col, rent_time_col, return_time_col):
                    continue
                rent_station = row[rent_col].strip()
                return_station = row[return_col].strip()
                rent_time = row[rent_time_col].strip()
                return_time = row[return_time_col].strip()

                if rent_station and rent_station != missing:
                    rental_counts[rent_station] += 1
                    hour = get_hour(rent_time, missing)
                    if hour is not None:
                        rent_hour_counts[(rent_station, hour)] += 1

                if return_station and return_station != missing:
                    return_counts[return_station] += 1
                    hour = get_hour(return_time, missing)
                    if hour is not None:
                        return_hour_counts[(return_station, hour)] += 1

    all_stations = set(rental_counts) | set(return_counts)
    net_flow = {
        station: return_counts.get(station, 0) - rental_counts.get(station, 0)
        for station in all_stations
    }

    shortage = sorted(net_flow.items(), key=lambda x: x[1])[:10]
    surplus = sorted(net_flow.items(), key=lambda x: x[1], reverse=True)[:10]

    sum_shortage = sum(val for _, val in shortage)
    sum_surplus = sum(val for _, val in surplus)

    neg_total = sum(val for val in net_flow.values() if val < 0)
    pos_total = sum(val for val in net_flow.values() if val > 0)

    share_shortage = abs(sum_shortage) / abs(neg_total) * 100 if neg_total else 0
    share_surplus = abs(sum_surplus) / abs(pos_total) * 100 if pos_total else 0

    abs_values = [abs(v) for v in net_flow.values()]
    mean_abs = sum(abs_values) / len(abs_values) if abs_values else 0

    mean_shortage = abs(sum_shortage) / len(shortage) if shortage else 0
    ratio_shortage = mean_shortage / mean_abs if mean_abs else 0

    shortage_stations = [name for name, _ in shortage]
    hour_net = Counter()
    for station in shortage_stations:
        for hour in range(24):
            net = return_hour_counts.get((station, hour), 0) - rent_hour_counts.get(
                (station, hour), 0
            )
            hour_net[hour] += net

    peak_hours = [7, 8, 9, 15, 16]
    peak_sum = sum(hour_net[h] for h in peak_hours)
    share_peak_of_shortage = (
        abs(peak_sum) / abs(sum_shortage) * 100 if sum_shortage else 0
    )

    print("top_rentals")
    for name, cnt in rental_counts.most_common(10):
        print(f"{name}\t{cnt}")

    print("\nshortage_top10_net (returns-rentals)")
    for name, val in shortage:
        print(f"{name}\t{val}")

    print("\nsurplus_top10_net (returns-rentals)")
    for name, val in surplus:
        print(f"{name}\t{val}")

    print("\nsummary")
    print(f"top10_shortage_sum\t{sum_shortage}")
    print(f"top10_surplus_sum\t{sum_surplus}")
    print(f"total_negative_sum\t{neg_total}")
    print(f"total_positive_sum\t{pos_total}")
    print(f"top10_shortage_share\t{share_shortage:.2f}%")
    print(f"top10_surplus_share\t{share_surplus:.2f}%")
    print(f"mean_abs_net_flow\t{mean_abs:.2f}")
    print(f"mean_shortage_net_flow\t{mean_shortage:.2f}")
    print(f"shortage_vs_mean_ratio\t{ratio_shortage:.2f}x")
    print(f"peak_hours_net_sum\t{peak_sum}")
    print(f"peak_hours_share\t{share_peak_of_shortage:.2f}%")


if __name__ == "__main__":
    main()
