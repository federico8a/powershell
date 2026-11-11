import unittest
from planner import calculate
class PlannerTests(unittest.TestCase):
    def setUp(self):
        self.c=dict(users=100,cad_per_user_month=5.4,data_gib=1000,
                    final_delta_gib=25,measured_gib_per_hour=20,
                    labor_hours=80,labor_cad_per_hour=100,source_monthly_cad=500,
                    overlap_months=2,one_time_tools_cad=1000,transfer_factor=1.3,
                    contingency_fraction=.2,cutover_validation_hours=2)
    def test_cost_and_time(self):
        r=calculate(self.c)
        self.assertEqual(r['target_monthly_cad'],540)
        self.assertEqual(r['transition_budget_cad'],12000)
        self.assertEqual(r['year_one_budget_cad'],18480)
        self.assertEqual(r['initial_transfer_hours'],65)
        self.assertEqual(r['reserved_cutover_hours'],3.62)
    def test_invalid_values(self):
        for k,v in [('users',-1),('users',1.5),('users',True),
                    ('measured_gib_per_hour',0),('data_gib',float('nan')),
                    ('cad_per_user_month','5.4'),('final_delta_gib',1001),
                    ('transfer_factor',.9),('contingency_fraction',1.1)]:
            with self.subTest(k=k,v=v):
                c={**self.c,k:v}
                with self.assertRaises(ValueError): calculate(c)
    def test_zero_scope(self):
        c={**self.c,'users':0,'data_gib':0,'final_delta_gib':0}
        self.assertEqual(calculate(c)['initial_transfer_hours'],0)
    def test_missing_required(self):
        del self.c['users']
        with self.assertRaises(ValueError): calculate(self.c)
if __name__=='__main__': unittest.main()
