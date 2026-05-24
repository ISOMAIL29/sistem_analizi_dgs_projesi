import re
from typing import Any


def latex_metin_onar(metin: Any) -> str:
    sonuc = "" if metin is None else str(metin)

    replacements = {
        "\b" + "ullet": r"\bullet",
        "\b" + "eta": r"\beta",
        "\b" + "ig": r"\big",
        "\b" + "ar": r"\bar",
        "\b" + "egin": r"\begin",
        "\t" + "ext": r"\text",
        "\t" + "imes": r"\times",
        "\t" + "heta": r"\theta",
        "\t" + "an": r"\tan",
        "\f" + "rac": r"\frac",
        "\f" + "loor": r"\floor",
        "\r" + "oot": r"\root",
        "\r" + "ight": r"\right",
    }

    for kaynak, hedef in replacements.items():
        sonuc = sonuc.replace(kaynak, hedef)

    sonuc = re.sub(r"(?<!\\)\bcdot\b", r"\\cdot", sonuc)
    sonuc = re.sub(r"(?<!\\)\btext\s*\(", r"\\text(", sonuc)
    sonuc = re.sub(r"(?<!\\)\bfrac\s*\{", r"\\frac{", sonuc)
    sonuc = re.sub(r"(?<!\\)\bsqrt\s*\{", r"\\sqrt{", sonuc)
    sonuc = re.sub(r"(?<!\\)\bsqrt\s*\(", r"\\sqrt(", sonuc)
    sonuc = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", "", sonuc)

    return sonuc


def latex_deger_onar(deger: Any) -> Any:
    if isinstance(deger, str):
        return latex_metin_onar(deger)
    if isinstance(deger, list):
        return [latex_deger_onar(item) for item in deger]
    if isinstance(deger, dict):
        return {anahtar: latex_deger_onar(value) for anahtar, value in deger.items()}
    return deger
