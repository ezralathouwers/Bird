import unittest
from build_species_details import reported_span,excerpt
class SpeciesDetailsImportTests(unittest.TestCase):
 def row(self,**changes):
  r={'needs_prediction':False,'model_used':'empirical','wingspan_reported_mid_all':25,'wingspan_reported_min_all':24,'wingspan_reported_max_all':26};r.update(changes);return r
 def test_predictions_are_excluded_even_with_numeric_values(self):
  self.assertIsNone(reported_span(self.row(needs_prediction=True)))
  self.assertIsNone(reported_span(self.row(model_used='order')))
 def test_real_range_is_not_replaced_by_midpoint(self):
  self.assertEqual(reported_span(self.row()),{'minimumCM':24,'maximumCM':26})
 def test_nan_and_absent_measurements_are_not_published(self):
  self.assertIsNone(reported_span(self.row(wingspan_reported_mid_all=float('nan'))))
  self.assertIsNone(reported_span(self.row(wingspan_reported_mid_all='NA')))
 def test_excerpt_preserves_complete_sentences(self):
  self.assertEqual(excerpt('Eerste zin. Tweede zin. Derde zin. Vierde zin.'),'Eerste zin. Tweede zin. Derde zin.')
if __name__=='__main__':unittest.main()
