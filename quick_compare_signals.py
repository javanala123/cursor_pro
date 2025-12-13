import csv
from pathlib import Path
from collections import defaultdict

# 한글 주석: 신호 문자열을 표준화(BUY/SELL/FLAT)하여 명칭 차이로 인한 불일치를 줄임
def normalize_sig(sig):
    if sig is None:
        return ''
    s = str(sig).strip().upper()
    if s in ('BUY', 'LONG', 'UP', 'BULL', 'BULLISH'):
        return 'BUY'
    if s in ('SELL', 'SHORT', 'DOWN', 'BEAR', 'BEARISH'):
        return 'SELL'
    if s in ('NONE', 'FLAT', 'NEUTRAL', '', 'HOLD', 'WAIT'):
        return 'FLAT'
    return s

# 한글 주석: 다양한 인코딩을 시도하여 텍스트 라인을 안전히 읽기
def read_text_lines(path):
    encodings = ['utf-8-sig', 'utf-8', 'utf-16', 'utf-16-le', 'utf-16-be', 'cp949', 'euc-kr', 'latin-1']
    for enc in encodings:
        try:
            with open(path, 'r', encoding=enc) as f:
                text = f.read().replace('\x00','')
                return text.splitlines()
        except Exception:
            continue
    # 최종 폴백: 바이너리로 읽어 손상 문자는 무시
    with open(path, 'rb') as f:
        return f.read().replace(b'\x00', b'').decode('latin-1', errors='ignore').splitlines()

# 한글 주석: 탭/콤마 자동 감지하여 행을 파싱
def parse_line(line):
    line = line.strip()
    if not line:
        return []
    if '\t' in line:
        return line.split('\t')
    if ',' in line:
        return [c.strip() for c in line.split(',')]
    # 한글 주석: 콤마/탭이 없으면 모든 공백(스페이스 포함) 기준 분할
    return line.split()

def load_ea(path, symbol_filter=None, tf_filter=5):
    ea = {}
    reader = read_text_lines(path)
    print(f"[DBG] EA raw lines: {len(reader)}")
    # 헤더 감지: 첫 줄이 문자열 포함하면 건너뛰기
    start_idx = 1 if reader and not reader[0].split(',')[0].isdigit() and not reader[0].split('\t')[0].isdigit() else 0
    parse_ok = 0
    parse_err = 0
    filter_sym_skip = 0
    filter_tf_skip = 0
    for i in range(start_idx, len(reader)):
        cols = parse_line(reader[i])
        if len(cols) < 4:
            parse_err += 1
            continue
        try:
            t = int(float(cols[0]))
            sym = cols[1]
            tf = int(cols[2])
            sig = normalize_sig(cols[3])
        except Exception:
            parse_err += 1
            continue
        if symbol_filter and sym != symbol_filter:
            filter_sym_skip += 1
            continue
        if tf_filter is not None and tf != tf_filter:
            filter_tf_skip += 1
            continue
        ea[t] = sig
        parse_ok += 1
    print(f"[DBG] EA parse_ok={parse_ok}, parse_err={parse_err}, tf_skip={filter_tf_skip}, sym_skip={filter_sym_skip}, kept={len(ea)}")
    # 샘플 3개
    if ea:
        ks = sorted(ea.keys())[:3]
        print(f"[DBG] EA sample: {[ (k, ea[k]) for k in ks ]}")
    return ea

def load_indicator(path, symbol_filter=None, tf_filter=1):
    buckets = defaultdict(list)
    reader = read_text_lines(path)
    print(f"[DBG] INDI raw lines: {len(reader)}")
    start_idx = 1 if reader and not reader[0].split(',')[0].isdigit() and not reader[0].split('\t')[0].isdigit() else 0
    parse_ok = 0
    parse_err = 0
    filter_sym_skip = 0
    filter_tf_skip = 0
    for i in range(start_idx, len(reader)):
        cols = parse_line(reader[i])
        if len(cols) < 4:
            parse_err += 1
            continue
        try:
            t = int(float(cols[0]))
            sym = cols[1]
            tf = int(cols[2])
            sig = normalize_sig(cols[3])
        except Exception:
            parse_err += 1
            continue
        if symbol_filter and sym != symbol_filter:
            filter_sym_skip += 1
            continue
        if tf_filter is not None and tf != tf_filter:
            filter_tf_skip += 1
            continue
        # M1 → M5 버킷(5분) 변환: 하향 반올림(버킷 시작 = 오픈 시간)
        bucket = (t // 300) * 300
        buckets[bucket].append((t, sig))
        parse_ok += 1
    # 각 버킷에서 가장 최근 분 신호를 선택
    indi_open = {}
    indi_close = {}
    for bucket, items in buckets.items():
        items.sort(key=lambda x: x[0])
        last_sig = items[-1][1]
        indi_open[bucket] = last_sig                # 키: 버킷 시작(오픈)
        indi_close[bucket + 300] = last_sig         # 키: 버킷 종료(클로즈)
    print(f"[DBG] INDI parse_ok={parse_ok}, parse_err={parse_err}, tf_skip={filter_tf_skip}, sym_skip={filter_sym_skip}, buckets={len(indi_open)}")
    if indi_open:
        ks = sorted(indi_open.keys())[:3]
        print(f"[DBG] INDI(open) sample: {[ (k, indi_open[k]) for k in ks ]}")
    if indi_close:
        ks2 = sorted(indi_close.keys())[:3]
        print(f"[DBG] INDI(close) sample: {[ (k, indi_close[k]) for k in ks2 ]}")
    return indi_open, indi_close

def compare(ea_map, indi_map):
    ea_keys = set(ea_map.keys())
    indi_keys = set(indi_map.keys())
    union_keys = sorted(ea_keys | indi_keys)
    inter_keys = sorted(ea_keys & indi_keys)

    # 합집합 기준
    total_u = 0
    match_u = 0
    mismatches_u = []
    for k in union_keys:
        ea_sig = ea_map.get(k)
        indi_sig = indi_map.get(k)
        if ea_sig is None and indi_sig is None:
            continue
        total_u += 1
        if ea_sig == indi_sig:
            match_u += 1
        else:
            mismatches_u.append((k, ea_sig, indi_sig))

    # 교집합 기준
    total_i = len(inter_keys)
    match_i = 0
    mismatches_i = []
    for k in inter_keys:
        if ea_map.get(k) == indi_map.get(k):
            match_i += 1
        else:
            mismatches_i.append((k, ea_map.get(k), indi_map.get(k)))

    return (total_u, match_u, mismatches_u, union_keys), (total_i, match_i, mismatches_i, inter_keys)

# 한글 주석: 여러 시간 오프셋(초)을 시도하여 교집합 일치율이 최대가 되는 정렬을 찾는다
def best_align(ea_map, indi_map, offsets):
    best = {
        'offset': 0,
        'rate_i': -1.0,
        'rate_u': -1.0,
        'tu': 0,
        'mu': 0,
        'ti': 0,
        'mi': 0,
        'mism_i': [],
        'mism_u': [],
    }
    for off in offsets:
        shifted = indi_map if off == 0 else {k+off: v for k, v in indi_map.items()}
        (tu, mu, mism_u, _), (ti, mi, mism_i, _) = compare(ea_map, shifted)
        rate_u = (mu/tu*100.0) if tu else 0.0
        rate_i = (mi/ti*100.0) if ti else 0.0
        # 우선순위: 교집합 일치율 > 교집합 표본수 > 합집합 일치율
        better = False
        if rate_i > best['rate_i']:
            better = True
        elif rate_i == best['rate_i'] and ti > best['ti']:
            better = True
        elif rate_i == best['rate_i'] and ti == best['ti'] and rate_u > best['rate_u']:
            better = True
        if better:
            best = {
                'offset': off,
                'rate_i': rate_i,
                'rate_u': rate_u,
                'tu': tu,
                'mu': mu,
                'ti': ti,
                'mi': mi,
                'mism_i': mism_i,
                'mism_u': mism_u,
            }
    return best

def main():
    base = Path(__file__).resolve().parent
    ea_path = str(base / 'signals_ea.csv')
    indi_path = str(base / 'signals_indi.csv')
    symbol = None  # 'XAUUSDm' 등 특정 심볼만 비교하려면 값 설정
    ea = load_ea(ea_path, symbol_filter=symbol, tf_filter=5)
    indi_open, indi_close = load_indicator(indi_path, symbol_filter=symbol, tf_filter=1)
    # 디버그: 로딩된 개수와 샘플 키 출력
    try:
        ea_keys = sorted(ea.keys())
        indi_o_keys = sorted(indi_open.keys())
        indi_c_keys = sorted(indi_close.keys())
        print(f"EA 로드: {len(ea_keys)}건, 예시키: {ea_keys[:3]}")
        print(f"INDI(M1→M5 open) 로드: {len(indi_o_keys)}건, 예시키: {indi_o_keys[:3]}")
        print(f"INDI(M1→M5 close) 로드: {len(indi_c_keys)}건, 예시키: {indi_c_keys[:3]}")
    except Exception:
        pass
    # 시간 범위 겹치는 구간으로 open/close 두 기준 모두 1차 축소
    if ea_keys:
        min_ea, max_ea = ea_keys[0], ea_keys[-1]
        indi_o = {k:v for k,v in indi_open.items() if min_ea <= k <= max_ea}
        indi_c = {k:v for k,v in indi_close.items() if min_ea <= k <= max_ea}
        print(f"INDI(open) 범위 축소: {len(indi_o)}건 (EA범위 {min_ea}~{max_ea})")
        print(f"INDI(close) 범위 축소: {len(indi_c)}건 (EA범위 {min_ea}~{max_ea})")
    else:
        indi_o, indi_c = indi_open, indi_close

    # 한글 주석: 오프셋 후보(초) 범위/해상도 설정: -900 ~ +900, 30초 간격
    OFFSET_MAX = 900
    OFFSET_STEP = 30
    offsets = list(range(-OFFSET_MAX, OFFSET_MAX + 1, OFFSET_STEP))
    best_open = best_align(ea, indi_o, offsets)
    best_close = best_align(ea, indi_c, offsets)
    print(f"[open] offset={best_open['offset']}s | 합집합: {best_open['tu']}개/{best_open['mu']}개 {best_open['rate_u']:.2f}% | 교집합: {best_open['ti']}개/{best_open['mi']}개 {best_open['rate_i']:.2f}%")
    print(f"[close] offset={best_close['offset']}s | 합집합: {best_close['tu']}개/{best_close['mu']}개 {best_close['rate_u']:.2f}% | 교집합: {best_close['ti']}개/{best_close['mi']}개 {best_close['rate_i']:.2f}%")

    # 더 높은 교집합 일치율 기준 선택(동률이면 표본수 큰 쪽)
    pick_close = False
    if best_close['rate_i'] > best_open['rate_i']:
        pick_close = True
    elif best_close['rate_i'] == best_open['rate_i'] and best_close['ti'] > best_open['ti']:
        pick_close = True

    chosen = 'close' if pick_close else 'open'
    best = best_close if pick_close else best_open
    mism_i = best['mism_i']
    mism_u = best['mism_u']
    print(f"선택된 기준: {chosen}, offset={best['offset']}s")

    # 한글 주석: 상태 대 상태 비교 추가(EA 이벤트를 상태로 전개)
    def build_state_from_events(events_map, timeline_keys, model='flip'):
        # model='flip': BUY→BUY 지속, SELL→SELL 지속(양방향 포지션 가정)
        # model='long_flat': BUY→BUY 지속, SELL→FLAT(롱만 운용 가정)
        # model='short_flat': SELL→SELL 지속, BUY→FLAT(숏만 운용 가정)
        state_map = {}
        current = 'FLAT'
        for t in sorted(timeline_keys):
            sig = events_map.get(t)
            if model == 'flip':
                if sig in ('BUY', 'SELL'):
                    current = sig
            elif model == 'long_flat':
                if sig == 'BUY':
                    current = 'BUY'
                elif sig == 'SELL':
                    current = 'FLAT'
            elif model == 'short_flat':
                if sig == 'SELL':
                    current = 'SELL'
                elif sig == 'BUY':
                    current = 'FLAT'
            state_map[t] = current
        return state_map

    # 선택된 기준/오프셋을 적용한 인디케이터 상태 타임라인 구성
    indi_base = indi_c if pick_close else indi_o
    if best['offset'] != 0:
        indi_base = {k + best['offset']: v for k, v in indi_base.items()}
    timeline = sorted(indi_base.keys())
    indi_state = {k: indi_base.get(k, 'FLAT') for k in timeline}
    # 세 가지 모델을 시험하고 최고 일치율을 선택
    state_models = ['flip', 'long_flat', 'short_flat']
    best_state = {'model': 'flip', 'total': 0, 'match': -1, 'rate': -1.0, 'mismatches': []}
    for mdl in state_models:
        ea_state = build_state_from_events(ea, timeline, model=mdl)
        total_s = len(timeline)
        match_s = sum(1 for k in timeline if ea_state.get(k) == indi_state.get(k))
        mismatches_state = [(k, ea_state.get(k), indi_state.get(k)) for k in timeline if ea_state.get(k) != indi_state.get(k)]
        rate_s = (match_s / total_s * 100.0) if total_s else 0.0
        print(f"[state:{mdl}] 타임라인 {total_s}개 중 일치 {match_s}개, {rate_s:.2f}%")
        if rate_s > best_state['rate']:
            best_state = {'model': mdl, 'total': total_s, 'match': match_s, 'rate': rate_s, 'mismatches': mismatches_state}

    # 한글 주석: 이벤트 대 이벤트 비교(인디케이터 변화 시점 추출, 허용 오차 내 매칭)
    def extract_events_from_state(state_map):
        events = []
        prev = None
        for t in sorted(state_map.keys()):
            cur = state_map[t]
            if prev is None:
                prev = cur
                continue
            if cur != prev:
                events.append((t, cur))
                prev = cur
        return events

    indi_events = extract_events_from_state(indi_state)
    ea_events = sorted([(t, s) for t, s in ea.items()])
    TOL = 180  # 초
    matched = 0
    mismatches_event = []
    used_idx = set()
    for et, es in ea_events:
        # 가까운 인디 이벤트 탐색
        best_j = -1
        best_dt = 10**12
        for j, (it, isg) in enumerate(indi_events):
            if j in used_idx:
                continue
            dt = abs(it - et)
            if dt < best_dt:
                best_dt = dt
                best_j = j
        if best_j >= 0 and best_dt <= TOL:
            # 방향까지 같은지 확인
            if es == indi_events[best_j][1]:
                matched += 1
            else:
                mismatches_event.append((et, es, indi_events[best_j][1]))
            used_idx.add(best_j)
        else:
            mismatches_event.append((et, es, ''))
    total_event = len(ea_events)
    rate_event = (matched / total_event * 100.0) if total_event else 0.0
    print(f"[event] EA 이벤트 {total_event}개 중 매칭 {matched}개(±{TOL}s), {rate_event:.2f}%")

    # 상세 리포트 파일 저장(선택 기준의 교집합/합집합 불일치 + 상태 불일치)
    with open('signal_compare_report.csv', 'w', newline='', encoding='utf-8-sig') as f:
        w = csv.writer(f)
        w.writerow(['time','ea_signal','indi_signal','basis'])
        for t, e, i in mism_i:
            w.writerow([t, e or '', i or '', 'intersection'])
        for t, e, i in mism_u:
            w.writerow([t, e or '', i or '', 'union'])
        for t, e, i in best_state['mismatches']:
            w.writerow([t, e or '', i or '', 'state'])
        for t, e, i in mismatches_event:
            w.writerow([t, e or '', i or '', 'event'])
    print("signal_compare_report.csv 저장 완료")
    # 요약 저장
    with open('signal_compare_summary.txt', 'w', encoding='utf-8-sig') as f:
        f.write(f"open_best_offset={best_open['offset']}\nopen_union_total={best_open['tu']}\nopen_union_match={best_open['mu']}\nopen_union_rate={best_open['rate_u']:.2f}\n")
        f.write(f"open_inter_total={best_open['ti']}\nopen_inter_match={best_open['mi']}\nopen_inter_rate={best_open['rate_i']:.2f}\n")
        f.write(f"close_best_offset={best_close['offset']}\nclose_union_total={best_close['tu']}\nclose_union_match={best_close['mu']}\nclose_union_rate={best_close['rate_u']:.2f}\n")
        f.write(f"close_inter_total={best_close['ti']}\nclose_inter_match={best_close['mi']}\nclose_inter_rate={best_close['rate_i']:.2f}\n")
        f.write(f"chosen_basis={chosen}\nchosen_offset={best['offset']}\n")
        f.write(f"state_model={best_state['model']}\nstate_total={best_state['total']}\nstate_match={best_state['match']}\nstate_rate={best_state['rate']:.2f}\n")
        f.write(f"event_tol_sec={TOL}\nevent_total={total_event}\nevent_match={matched}\nevent_rate={rate_event:.2f}\n")
    print("signal_compare_summary.txt 저장 완료")

if __name__ == '__main__':
    main()


