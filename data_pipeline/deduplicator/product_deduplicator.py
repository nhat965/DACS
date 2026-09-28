from __future__ import annotations

import re
from copy import deepcopy
from typing import Any


def _norm_name(value: Any) -> str:
    text = (str(value) if value is not None else '').casefold().strip()
    return re.sub(r'[^a-z0-9]+', '', text)


def identity_keys(raw: dict[str, Any], processed: dict[str, Any]) -> list[tuple[str, str]]:
    keys: list[tuple[str, str]] = []
    sku = processed.get('sku')
    if sku: keys.append(('sku', str(sku).casefold()))
    source_id = raw.get('source_product_id') or raw.get('product_id_raw')
    if source_id: keys.append(('source_product_id', f"{raw.get('source_name','')}:{source_id}".casefold()))
    url = processed.get('source_url')
    if url: keys.append(('canonical_url', str(url).casefold()))
    brand, name, volume = processed.get('brand_normalized'), processed.get('name'), processed.get('volume')
    if brand and name and volume:
        keys.append(('brand_name_volume', f'{str(brand).casefold()}|{_norm_name(name)}|{str(volume).casefold()}'))
    return keys


def _present(v: Any) -> bool:
    return v not in (None, '', [], {})


def _merge_value(field: str, old: Any, new: Any) -> Any:
    if not _present(old): return deepcopy(new)
    if not _present(new): return old
    if field in {'skin_types','skin_concerns','care_goals'} and isinstance(old, list) and isinstance(new, list):
        return list(dict.fromkeys([*old, *new]))
    if field in {'description','benefits','inci_ingredients','key_ingredients','usage_instruction','warnings'}:
        return new if len(str(new)) > len(str(old)) else old
    if field == 'source_url':
        # Prefer canonical /products/ form over collection-wrapped product URLs.
        def rank(u: Any) -> tuple[int,int]:
            s=str(u); return (0 if re.search(r'/products/[^/]+/?$', s) and '/collections/' not in s else 1, len(s))
        return min([old,new], key=rank)
    return old


def merge_duplicates(items: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    groups: list[dict[str, Any]] = []
    key_to_group: dict[tuple[str,str], int] = {}
    report: list[dict[str, Any]] = []
    for idx, item in enumerate(items):
        keys = identity_keys(item['raw'], item['processed'])
        matches = [key_to_group[k] for k in keys if k in key_to_group]
        if not matches:
            gi=len(groups)
            merged=deepcopy(item)
            merged['processed'].setdefault('_processing', {})['merged_source_count']=1
            merged['processed']['_processing']['source_urls']=[item['processed'].get('source_url')] if item['processed'].get('source_url') else []
            groups.append(merged)
            for k in keys: key_to_group.setdefault(k,gi)
            continue
        gi=matches[0]
        target=groups[gi]
        before=deepcopy(target['processed'])
        for field, value in item['processed'].items():
            if field == '_processing': continue
            target['processed'][field]=_merge_value(field,target['processed'].get(field),value)
        tm=target['processed'].setdefault('_processing',{})
        sm=item['processed'].get('_processing',{})
        tm['merged_source_count']=int(tm.get('merged_source_count',1))+1
        urls=tm.setdefault('source_urls',[])
        if item['processed'].get('source_url') and item['processed']['source_url'] not in urls: urls.append(item['processed']['source_url'])
        # Preserve all unmapped evidence, while later validation operates on merged normalized fields.
        tu=tm.setdefault('unmapped_values',{})
        for f, vals in (sm.get('unmapped_values',{}) or {}).items():
            bucket=tu.setdefault(f,[])
            for v in vals or []:
                if v not in bucket: bucket.append(v)
        fp=tm.setdefault('field_provenance',{})
        for f,p in (sm.get('field_provenance',{}) or {}).items():
            if not _present(before.get(f)) and _present(target['processed'].get(f)): fp[f]=p
        report.append({'index':idx,'merged_into_index':gi,'matched_by':next((k[0] for k in keys if k in key_to_group and key_to_group[k]==gi),None),'source_url':item['processed'].get('source_url')})
        for k in keys: key_to_group[k]=gi
    for g in groups:
        g['processed'].setdefault('_processing',{})['is_duplicate']=False
    return groups, report

# Backward-compatible name used by older callers.
mark_duplicates = merge_duplicates
