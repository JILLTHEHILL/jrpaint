import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SOUND_DIR = ROOT.parent / "sound_effects"
OUT_MEM = ROOT / "color_audio.mem"
OUT_TABLE = ROOT / "color_audio_table.vh"

TARGET_SR = 8000
ORDER = [
    ("White", 1),
    ("Pink", 2),
    ("Red", 3),
    ("Orange", 4),
    ("Yellow", 5),
    ("Green", 6),
    ("Blue", 7),
    ("Purple", 8),
    ("Brown", 9),
    ("Black", 10),
]


def decode_sample(raw: bytes, sampwidth: int) -> int:
    if sampwidth == 1:
        return raw[0] - 128
    return int.from_bytes(raw, byteorder="little", signed=True)


def resample_linear(samples: list[int], src_sr: int, dst_sr: int) -> list[int]:
    if src_sr == dst_sr or len(samples) <= 1:
        return samples[:]

    dst_len = max(1, int(round(len(samples) * dst_sr / src_sr)))
    if dst_len == 1:
        return [samples[0]]

    out = []
    last = len(samples) - 1
    for i in range(dst_len):
        pos = (i * last) / (dst_len - 1)
        base = int(pos)
        frac = pos - base
        left = samples[base]
        right = samples[base + 1] if base < last else samples[last]
        out.append(int(round(left + ((right - left) * frac))))
    return out


def load_pcm_u8(wav_path: Path) -> list[int]:
    with wave.open(str(wav_path), "rb") as wav:
        if wav.getcomptype() != "NONE":
            raise ValueError(f"{wav_path.name}: compressed WAV files are not supported")

        src_sr = wav.getframerate()
        channels = wav.getnchannels()
        sampwidth = wav.getsampwidth()
        raw = wav.readframes(wav.getnframes())

    if channels not in (1, 2):
        raise ValueError(f"{wav_path.name}: only mono or stereo WAV files are supported")

    frame_width = channels * sampwidth
    samples = []

    for offset in range(0, len(raw), frame_width):
        total = 0
        for channel in range(channels):
            start = offset + (channel * sampwidth)
            stop = start + sampwidth
            total += decode_sample(raw[start:stop], sampwidth)
        samples.append(total // channels)

    samples = resample_linear(samples, src_sr, TARGET_SR)
    peak = max((abs(sample) for sample in samples), default=0) or 1

    pcm_u8 = []
    for sample in samples:
        value = int(round((sample * 127.0 / peak) + 128.0))
        if value < 0:
            value = 0
        elif value > 255:
            value = 255
        pcm_u8.append(value)

    return pcm_u8


def main() -> None:
    samples = []
    offsets = {}
    lengths = {}
    cursor = 0

    for color_name, color_id in ORDER:
        wav_path = SOUND_DIR / f"{color_name}.wav"
        pcm_u8 = load_pcm_u8(wav_path)

        offsets[color_id] = cursor
        lengths[color_id] = len(pcm_u8)
        cursor += len(pcm_u8)
        samples.append(pcm_u8)

    merged = []
    for block in samples:
        merged.extend(block)

    with OUT_MEM.open("w", encoding="ascii") as fh:
        for value in merged:
            fh.write(f"{value:02x}\n")

    audio_aw = max(1, (len(merged) - 1).bit_length())
    with OUT_TABLE.open("w", encoding="ascii") as fh:
        fh.write(f"localparam integer AUDIO_DEPTH = {len(merged)};\n")
        fh.write(f"localparam integer AUDIO_AW = {audio_aw};\n")
        for color_name, color_id in ORDER:
            tag = color_name.upper()
            fh.write(f"localparam [AUDIO_AW-1:0] {tag}_START = {audio_aw}'d{offsets[color_id]};\n")
            fh.write(f"localparam [AUDIO_AW-1:0] {tag}_LEN = {audio_aw}'d{lengths[color_id]};\n")

    print(f"wrote {OUT_MEM} with {len(merged)} samples at {TARGET_SR} Hz")
    print(f"wrote {OUT_TABLE}")
    for color_name, color_id in ORDER:
        print(
            f"{color_name:6s} color={color_id:2d} "
            f"offset={offsets[color_id]:6d} length={lengths[color_id]:6d}"
        )


if __name__ == "__main__":
    main()
