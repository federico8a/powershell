"""Offline, dependency-free CAD cost and transfer planner. No network access."""
import argparse, json, math

def number(c, key, default=None, positive=False, integer=False):
    v=c.get(key,default)
    if isinstance(v,bool) or not isinstance(v,(int,float)) or not math.isfinite(v):
        raise ValueError(f'{key}: finite number required')
    if v < 0 or (positive and v == 0) or (integer and int(v)!=v):
        raise ValueError(f'{key}: invalid range or non-integer count')
    return v

def calculate(c):
    users=number(c,'users',integer=True)
    price=number(c,'cad_per_user_month')
    overlap=number(c,'overlap_months',0)
    source=number(c,'source_monthly_cad',0)
    extra=number(c,'extra_recurring_monthly_cad',0)
    gb=number(c,'data_gib')
    delta=number(c,'final_delta_gib')
    if delta>gb: raise ValueError('final delta cannot exceed scoped data')
    rate=number(c,'measured_gib_per_hour',positive=True)
    factor=number(c,'transfer_factor',1.3,positive=True)
    if factor<1: raise ValueError('transfer_factor must be >= 1')
    hourly=number(c,'labor_cad_per_hour',0)
    labor=number(c,'labor_hours',0)*hourly
    tools=number(c,'one_time_tools_cad',0)
    contingency=number(c,'contingency_fraction',0.2)
    if contingency>1: raise ValueError('contingency_fraction must be <= 1')
    validation=number(c,'cutover_validation_hours',2)
    recurring=users*price+extra
    one_time=(labor+tools+source*overlap)*(1+contingency)
    return {'currency':'CAD','tax_included':False,
        'target_monthly_cad':round(recurring,2),
        'target_annual_cad':round(recurring*12,2),
        'transition_budget_cad':round(one_time,2),
        'year_one_budget_cad':round(recurring*12+one_time,2),
        'initial_transfer_hours':round(gb/rate*factor,2),
        'final_delta_transfer_hours':round(delta/rate*factor,2),
        'reserved_cutover_hours':round(delta/rate*factor+validation,2),
        'caveat':'Planning estimate, not outage prediction or Microsoft SLA. No parallelism assumption.'}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('config')
    a=p.parse_args()
    try:
        with open(a.config,encoding='utf-8') as f: c=json.load(f)
        print(json.dumps(calculate(c),indent=2,allow_nan=False))
    except (ValueError,OSError,TypeError) as e:
        p.exit(2,f'Invalid configuration: {e}\n')
