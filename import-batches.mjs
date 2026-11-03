// Bound both row count and payload size; sequential chunks keep retry offsets deterministic.
export function importBatch(rows,offset,maxRows=2000,maxBytes=1000000){let bytes=0,end=offset;while(end<rows.length&&end-offset<maxRows){const size=new TextEncoder().encode(JSON.stringify(rows[end])).length+1;if(end>offset&&bytes+size>maxBytes)break;bytes+=size;end++}return rows.slice(offset,end)}
