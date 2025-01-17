///|
pub(all) struct DataFrame {
  mut data : Array[Series]
  mut shape : Array[Int]
  mut index : Map[String, Int]
}

///|
let emptyDataFrame : DataFrame = DataFrame::{
  data: [],
  shape: [0, 0],
  index: {},
}

///|
type! InconsistentSeriesLength String derive(Show)

///|
type! DuplicateColumnError String derive(Show)

///|
type! ColumnNotFoundError String derive(Show)

///|
type! IndexOutOfBounds String derive(Show)

///|
type! InvalidType String derive(Show)

///| Create a new DataFrame
///
/// ### Parameters
///
/// - `data` : Array of Series
///
/// ### Return
///
/// - `DataFrame!InconsistentSeriesLength` : A new DataFrame instance
///
/// ### Errors
///
/// - `InconsistentSeriesLength` : Raised if the lengths of the Series are not equal
///
/// ### Example
/// ```
/// let df = DataFrame::new!([
///   Series::new("A", SeriesData::Int([1, 1, 3, 1, 1, 6])),
///   Series::new("B", SeriesData::Float([1.5, 2.0, 3.5, 4.0, 5.5, 6.0])),
///   Series::new("C", SeriesData::Bool([true, false, true, false, true, false])),
///   Series::new("D", SeriesData::Str(["a", "b", "c", "d", "e", "f"])),
/// ])
/// ```
pub fn DataFrame::new(
  data : Array[Series]
) -> DataFrame!InconsistentSeriesLength {
  let index : Map[String, Int] = {}
  for i = 0; i < data.length(); i = i + 1 {
    if data[i].data().length() != data[0].data().length() {
      raise InconsistentSeriesLength(
        "Could not create a new DataFrame. The Series lengths are not equal.",
      )
    }
    index[data[i].name()] = i
  }
  DataFrame::{ data, shape: [data[0].data().length(), data.length()], index }
}

///|
pub fn DataFrame::shape(self : DataFrame) -> Array[Int] {
  self.shape
}

///|
pub fn DataFrame::data(self : DataFrame) -> Array[Series] {
  self.data
}

///| Trait Show for DataFrame
pub impl Show for DataFrame with output(self, logger) {
  let mut row_str = "\t"
  for col in self.data {
    row_str = row_str + col.name() + "\t"
  }
  logger.write_string(row_str + "\n")
  row_str = ""
  for i = 0; i < self.shape()[0]; i = i + 1 {
    row_str += i.to_string() + "\t"
    for col in self.data {
      match col.data() {
        SeriesData::Int(vals) => row_str += vals[i].to_string() + "\t"
        SeriesData::Float(vals) => row_str += vals[i].to_string() + "\t"
        SeriesData::Bool(vals) => row_str += vals[i].to_string() + "\t"
        SeriesData::Str(vals) => row_str += vals[i] + "\t"
      }
    }
    row_str += "\n"
  }
  logger.write_string(row_str)
}

///| Display the first few rows of the DataFrame
///
/// ### Parameters
///
/// - `self` : An instance of the DataFrame
/// - `num` : The number of rows to display (default is 5)
///
/// ### Return
///
/// - `Unit` : This function prints the first few rows of the DataFrame
///
/// ### Example
/// ```
/// df.head()
/// df.head(rows=3)
/// ```
pub fn DataFrame::head(self : DataFrame, rows~ : Int = 5) -> Unit {
  let mut row_str = "\t"
  for col in self.data {
    row_str = row_str + col.name() + "\t"
  }
  row_str += "\n"
  for i = 0; i < @math.minimum(rows, self.shape()[0]); i = i + 1 {
    row_str += i.to_string() + "\t"
    for col in self.data {
      match col.data() {
        SeriesData::Int(vals) => row_str += vals[i].to_string() + "\t"
        SeriesData::Float(vals) => row_str += vals[i].to_string() + "\t"
        SeriesData::Bool(vals) => row_str += vals[i].to_string() + "\t"
        SeriesData::Str(vals) => row_str += vals[i] + "\t"
      }
    }
    row_str += "\n"
  }
  println(row_str)
}

///| Add a new column to the DataFrame
///
/// ### Parameters
///
/// - `self` : An instance of the DataFrame
/// - `col` : The Series to be added as a new column
///
/// ### Return
///
/// - `Unit!` : This function adds a new column to the DataFrame or raises an error
///
/// ### Errors
///
/// - `InconsistentSeriesLength`: Series length is not equal to the DataFrame length
/// - `DuplicateColumnError`: Series name already exists
///
/// ### Example
/// ```
/// let new_column = Series::new("B", SeriesData::Int([1, 2, 3]))
/// df.add_column(new_column)
/// ```
pub fn DataFrame::add_column(self : DataFrame, col : Series) -> Unit! {
  if col.data().length() != self.shape()[0] {
    raise InconsistentSeriesLength(
      "Could not add a new column to the DataFrame. The Series lengths are not equal.",
    )
  }
  if self.index.contains(col.name()) {
    raise DuplicateColumnError(
      "Could not add a new column to the DataFrame. The Series name already exists.",
    )
  }
  self.data += [col]
  self.shape = [self.shape()[0], self.shape()[1] + 1]
  self.index[col.name()] = self.shape()[1] - 1
}

///| Drop a column from the DataFrame
///
/// ### Parameters
///
/// - `self` : An instance of the DataFrame
/// - `col_name` : The name of the column to be dropped
///
/// ### Return
///
/// - `Unit` : This function drops a column from the DataFrame
///
/// ### Example
/// ```
/// df.drop_column("column_name")
/// ```
pub fn DataFrame::drop_column(
  self : DataFrame,
  col_name : String
) -> Unit!ColumnNotFoundError {
  match self.index.get(col_name) {
    Some(idx) => {
      let _ = self.data.remove(idx)
      self.index.remove(col_name)
      self.shape = [self.shape()[0], self.shape()[1] - 1]
      self.index.each(fn(k, v) { if v > idx { self.index[k] = v - 1 } })
    }
    None => raise ColumnNotFoundError("Column '\{col_name}' not found")
  }
}

///| Rename a column in the DataFrame
///
/// ### Parameters
///
/// - `self` : An instance of the DataFrame
/// - `old_name` : The current name of the column to be renamed
/// - `new_name` : The new name for the column
///
/// ### Return
///
/// - `Unit` : This function renames a column in the DataFrame
/// 
/// ### Errors
/// 
/// - `ColumnNotFoundError` : Raised if the column is not found
///
/// ### Example
/// ```
/// test {
///   let mut df = DataFrame::new([Series::new("A", SeriesData::Int([1, 2]))])
///   df.rename("A", "B")
///   inspect!(df.data()[0].name(), context="B")
/// }
/// ```
pub fn DataFrame::rename(
  self : DataFrame,
  old_name : String,
  new_name : String
) -> Unit!ColumnNotFoundError {
  match self.index.get(old_name) {
    Some(idx) => self.data[idx].name = new_name
    None => raise ColumnNotFoundError("Column '\{old_name}' not found")
  }
}

///| Select a column from the DataFrame
///
/// ### Parameters
///
/// - `self` : An instance of the DataFrame
/// - `col_name` : Column name to be selected
///
/// ### Return
///
/// - `Series` : Series contain selected columns
/// 
/// ### Errors
/// 
/// - `ColumnNotFoundError` : Raised if a column is not found
///
/// ### Example
/// ```
/// let col_selected = df.column("col_name")
/// ```
pub fn DataFrame::column(
  self : DataFrame,
  col_name : String
) -> Series!ColumnNotFoundError {
  match self.index.get(col_name) {
    Some(idx) => self.data[idx]
    None => raise ColumnNotFoundError("Column '\{col_name}' not found")
  }
}

///| Select specific columns from the DataFrame
///
/// ### Parameters
///
/// - `self` : An instance of the DataFrame
/// - `cols` : An array of column names to be selected
///
/// ### Return
///
/// - `DataFrame` : A new DataFrame containing only the selected columns
/// 
/// ### Errors
/// 
/// - `ColumnNotFoundError` : Raised if a column is not found
///
/// ### Example
/// ```
/// let df_selected = df.select_columns(["col_name1", "col_name2"])
/// ```
pub fn DataFrame::select_columns(
  self : DataFrame,
  cols : Array[String]
) -> DataFrame!ColumnNotFoundError {
  let selected_cols : Array[Series] = []
  let index : Map[String, Int] = {}
  for name in cols {
    match self.index.get(name) {
      Some(idx) => {
        selected_cols.push(self.data[idx])
        index[name] = selected_cols.length() - 1
      }
      None => raise ColumnNotFoundError("Column '\{name}' not found")
    }
  }
  DataFrame::{
    data: selected_cols,
    shape: [self.shape()[0], selected_cols.length()],
    index,
  }
}

///| Drop a row from the DataFrame
///
/// ### Parameters
///
/// - `self` : An instance of the DataFrame
/// - `row` : The index of the row to be dropped
///
/// ### Return
///
/// - `Unit` : This function drops a row from the DataFrame
///
/// ### Errors
///
/// - `IndexOutOfBounds` : Raised if the row index is out of bounds
///
/// ### Example
/// ```
/// df.drop_row(0)
/// ```
pub fn DataFrame::drop_row(self : DataFrame, row_index : Int) -> Unit! {
  if row_index < 0 || row_index >= self.shape()[0] {
    raise IndexOutOfBounds("Row index out of bounds")
  }
  for col in self.data {
    col.data.erase!(row_index)
  }
  self.shape[0] = self.shape[0] - 1
}

///| Add a new row to the DataFrame
///
/// ### Parameters
///
/// - `self` : An instance of the DataFrame
/// - `row` : An array of DType representing the new row to be added
///
/// ### Return
///
/// - `Unit` : This function adds a new row to the DataFrame
///
/// ### Errors
///
/// - `InconsistentSeriesLength` : Raised if the row length does not match the DataFrame column length
/// - `InvalidType` : if there is a type mismatch
///
/// ### Example
/// ```
/// let mut df = DataFrame::new([
///   Series::new("A", SeriesData::Int([1, 2, 3])), 
///   Series::new("B", SeriesData::Float([1.1, 2.2, 3.3]))
/// ])
/// df.add_row([DType::Int(4), DType::Float(4.4)])
/// ```
pub fn DataFrame::add_row(self : DataFrame, row : Array[DType]) -> Unit! {
  if row.length() != self.shape()[1] {
    raise InconsistentSeriesLength(
      "Row length does not match DataFrame column length",
    )
  }
  for i = 0; i < row.length(); i = i + 1 {
    match self.data[i].data {
      SeriesData::Int(data) =>
        match row[i] {
          DType::Int(value) => data.push(value)
          _ => raise InvalidType("Type mismatch")
        }
      SeriesData::Float(data) =>
        match row[i] {
          DType::Float(value) => data.push(value)
          _ => raise InvalidType("Type mismatch")
        }
      SeriesData::Bool(data) =>
        match row[i] {
          DType::Bool(value) => data.push(value)
          _ => raise InvalidType("Type mismatch")
        }
      SeriesData::Str(data) =>
        match row[i] {
          DType::Str(value) => data.push(value)
          _ => raise InvalidType("Type mismatch")
        }
    }
  }
  self.shape[0] = self.shape[0] + 1
}

///| Select specific rows from the DataFrame
///
/// ### Parameters
///
/// - `self` : An instance of the DataFrame
/// - `range` : An optional tuple representing the range of rows to be selected (inclusive start, exclusive end)
/// - `indices` : An optional array of row indices to be selected
///
/// ### Return
///
/// - `DataFrame` : A new DataFrame containing only the selected rows
/// 
/// ### Errors
/// 
/// - `IndexOutOfBounds` : Raised if the row index is out of bounds
///
/// ### Example
/// ```
/// let df_selected_range = df.select_rows(range=(1, 4))
/// 
/// let df_selected_indices = df.select_rows(indices=[1, 3, 5])
/// ```
pub fn DataFrame::select_rows(
  self : DataFrame,
  range? : (Int, Int),
  indices? : Array[Int]
) -> DataFrame!IndexOutOfBounds {
  match (range, indices) {
    (Some(_), Some(_)) | (Some(_), None) => {
      let selected_rows : Array[Series] = []
      for col in self.data {
        let (begin, end) = match range {
          Some(r) => r
          None => abort("Range is None")
        }
        let select_data = match col.data() {
          SeriesData::Int(data) =>
            SeriesData::Int(data.split_at(begin).1.split_at(end - begin).0)
          SeriesData::Float(data) =>
            SeriesData::Float(data.split_at(begin).1.split_at(end - begin).0)
          SeriesData::Bool(data) =>
            SeriesData::Bool(data.split_at(begin).1.split_at(end - begin).0)
          SeriesData::Str(data) =>
            SeriesData::Str(data.split_at(begin).1.split_at(end - begin).0)
        }
        selected_rows.push(Series::new(col.name(), select_data))
      }
      DataFrame::{
        data: selected_rows,
        shape: [selected_rows[0].data.length(), self.shape()[1]],
        index: self.index,
      }
    }
    (None, Some(_)) =>
      match indices {
        Some(i) => {
          i.sort()
          if i[0] < 0 || i[i.length() - 1] >= self.shape()[0] {
            raise IndexOutOfBounds("Row index out of bounds")
          }
          let selected_rows : Array[Series] = []
          for col in self.data {
            match col.data {
              SeriesData::Int(data) => {
                let col_data = []
                for idx in i {
                  col_data.push(data[idx])
                }
                selected_rows.push(
                  Series::new(col.name(), SeriesData::Int(col_data)),
                )
              }
              SeriesData::Float(data) => {
                let col_data = []
                for idx in i {
                  col_data.push(data[idx])
                }
                selected_rows.push(
                  Series::new(col.name(), SeriesData::Float(col_data)),
                )
              }
              SeriesData::Bool(data) => {
                let col_data = []
                for idx in i {
                  col_data.push(data[idx])
                }
                selected_rows.push(
                  Series::new(col.name(), SeriesData::Bool(col_data)),
                )
              }
              SeriesData::Str(data) => {
                let col_data = []
                for idx in i {
                  col_data.push(data[idx])
                }
                selected_rows.push(
                  Series::new(col.name(), SeriesData::Str(col_data)),
                )
              }
            }
          }
          DataFrame::{
            data: selected_rows,
            shape: [selected_rows[0].data().length(), self.shape()[1]],
            index: self.index,
          }
        }
        None => emptyDataFrame
      }
    (None, None) => emptyDataFrame
  }
}

///| Filter rows in the DataFrame based on a condition
///
/// ### Parameters
///
/// - `self` : An instance of the DataFrame
/// - `name` : The name of the column to apply the filter on
/// - `f` : A function that takes a `DType` and returns a `Bool` indicating whether the row should be included
///
/// ### Return
///
/// - `DataFrame` : A new DataFrame containing only the rows that satisfy the condition
///
/// ### Example
/// ```
/// let df = DataFrame::new([Series::new("A", SeriesData::Int([1, 2, 3, 4, 5, 6]))])
/// let filtered = df.filter("A", fn(x) -> Bool { x < DType::Int(3) })
/// ```
pub fn DataFrame::filter(
  self : DataFrame,
  name : String,
  f : (DType) -> Bool
) -> DataFrame! {
  match self.index.get(name) {
    Some(index) =>
      match self.data[index].data() {
        SeriesData::Int(data) => {
          let rows = Array::new()
          for i = 0; i < data.length(); i = i + 1 {
            if f(DType::Int(data[i])) {
              rows.push(i)
            }
          }
          self.select_rows!(indices=rows)
        }
        SeriesData::Float(data) => {
          let rows = Array::new()
          for i = 0; i < data.length(); i = i + 1 {
            if f(DType::Float(data[i])) {
              rows.push(i)
            }
          }
          self.select_rows!(indices=rows)
        }
        SeriesData::Bool(data) => {
          let rows = Array::new()
          for i = 0; i < data.length(); i = i + 1 {
            if f(DType::Bool(data[i])) {
              rows.push(i)
            }
          }
          self.select_rows!(indices=rows)
        }
        SeriesData::Str(data) => {
          let rows = Array::new()
          for i = 0; i < data.length(); i = i + 1 {
            if f(DType::Str(data[i])) {
              rows.push(i)
            }
          }
          self.select_rows!(indices=rows)
        }
      }
    None => emptyDataFrame
  }
}

///| Sort the DataFrame by a specified column
///
/// ### Parameters
///
/// - `self` : An instance of the DataFrame
/// - `col_name` : The name of the column to sort by
/// - `descending~` : Whether to sort in descending order (default is false)
///
/// ### Return
///
/// - `Unit` : This function sorts the DataFrame in place
///
/// ### Errors
///
/// - `ColumnNotFoundError` : Raised if the specified column is not found
///
/// ### Example
/// ```
/// let df = DataFrame::new([
///   Series::new("A", SeriesData::Int([3, 1, 2])), 
///   Series::new("B", SeriesData::Float([3.3, 1.1, 2.2]))
/// ])
/// df.sort("A", descending=true)
/// inspect!(df.data()[0].data(), content="Int([1, 2, 3])")
/// ```
pub fn DataFrame::sort(
  self : DataFrame,
  col_name : String,
  descending~ : Bool = false
) -> Unit!ColumnNotFoundError {
  match self.index.get(col_name) {
    Some(index) => {
      let indices = self.data[index].data.get_argsort_indices(descending~)
      for item in self.data {
        item.data.argsort_indices(indices)
      }
    }
    None => raise ColumnNotFoundError("Column '\{col_name}' not found.")
  }
}

///| Vertically stack two DataFrames
///
/// ### Parameters
///
/// - `self` : An instance of the DataFrame
/// - `other` : Another DataFrame to be stacked vertically
///
/// ### Return
///
/// - `DataFrame` : A new DataFrame resulting from the vertical stacking of the two DataFrames
///
/// ### Errors
///
/// - `InconsistentSeriesLength` : Raised if the number of columns in the two DataFrames is not the same
/// - `InvalidType` : Raised if the data types of the corresponding columns in the two DataFrames are not the same
///
/// ### Example
/// ```
/// let df1 = DataFrame::new!([
///   Series::new("A", SeriesData::Int([1, 2, 3]))
/// ])
/// let df2 = DataFrame::new!([
///   Series::new("A", SeriesData::Int([4, 5, 6]))
/// ])
/// let df_stacked = df1.vstack!(df2)
/// ```
pub fn vstack(self : DataFrame, other : DataFrame) -> DataFrame! {
  if self.shape()[1] != other.shape()[1] {
    raise InconsistentSeriesLength("The number of columns must be the same.")
  }
  let data : Array[Series] = []
  for series in self.data {
    match (series.data, other.column!(series.name).data) {
      (SeriesData::Int(data1), SeriesData::Int(data2)) => {
        let new_data = data1 + data2
        data.push(Series::new(series.name, SeriesData::Int(new_data)))
      }
      (SeriesData::Float(data1), SeriesData::Float(data2)) => {
        let new_data = data1 + data2
        data.push(Series::new(series.name, SeriesData::Float(new_data)))
      }
      (SeriesData::Bool(data1), SeriesData::Bool(data2)) => {
        let new_data = data1 + data2
        data.push(Series::new(series.name, SeriesData::Bool(new_data)))
      }
      (SeriesData::Str(data1), SeriesData::Str(data2)) => {
        let new_data = data1 + data2
        data.push(Series::new(series.name, SeriesData::Str(new_data)))
      }
      _ => raise InvalidType("The data types must be the same.")
    }
  }
  DataFrame::new!(data)
}

///| Horizontally stack two DataFrames
///
/// ### Parameters
///
/// - `self` : An instance of the DataFrame
/// - `other` : Another DataFrame to be stacked horizontally
///
/// ### Return
///
/// - `DataFrame` : A new DataFrame resulting from the horizontal stacking of the two DataFrames
///
/// ### Example
/// ```
/// let df1 = DataFrame::new!([
///   Series::new("A", SeriesData::Int([1, 2, 3]))
/// ])
/// let df2 = DataFrame::new!([
///   Series::new("B", SeriesData::Int([4, 5, 6]))
/// ])
/// let df_stacked = df1.hstack!(df2)
/// ```
pub fn hstack(self : DataFrame, other : DataFrame) -> DataFrame! {
  let data : Array[Series] = other.data.copy()
  for series in self.data {
    if other.index.contains(series.name()) == false {
      data.push(series)
    }
  }
  DataFrame::new!(data)
}

///|
/// Clears all data in the DataFrame, resetting it to an empty state.
///
/// ### Parameters:
///
/// - `self` : The DataFrame to be cleared.
/// - `n` : Optional parameter that specifies a size hint for clearing (default
/// is 0). Currently not used.
///
/// ### Example:
///
/// ```moonbit
/// df.clear()
/// ```
pub fn DataFrame::clear(self : DataFrame) -> Unit {
  self.data.clear()
  self.shape = [0, 0]
  self.index.clear()
}

///|
/// Creates a deep copy of the DataFrame.
///
/// ### Parameters:
///
/// - `self` : The DataFrame to be cloned.
///
/// ### Return:
/// Return a new DataFrame with the same data, shape, and index as the original
/// DataFrame. All internal data structures are deeply copied.
/// THIS METHOD Under Consideration...
///
/// ### Example:
///
/// ```moonbit
/// let df = DataFrame::new!([
///   Series::new("A", SeriesData::Int([1, 2, 3])),
///   Series::new("B", SeriesData::Float([1.0, 2.0, 3.0])),
/// ])
/// let cloned = df.clone()
/// ```
pub fn DataFrame::clone(self : DataFrame) -> DataFrame {
  let data = self.data.map(fn(series : Series) { series.copy() })
  let index = self.index.iter().collect()
  let map : Map[String, Int] = {}
  for idx in index {
    map[idx.0] = idx.1
  }
  DataFrame::{ data, shape: self.shape.copy(), index: map }
}

pub(all) enum ColumnSelector {
  Int(Int)
  Str(String)
}
///|
/// Retrieves a single item from the DataFrame at the specified row and column.
///
/// ### Parameters:
///
/// - `self` : The DataFrame to retrieve the item from.
/// - `row` : The index of the row (zero-based).
/// - `column` : The column identifier, can be either:
///  * `ColumnSelector::Int`: A zero-based index of the column
///  * `ColumnSelector::Str`: The name of the column
///
/// Returns a `DType` value representing the item at the specified position.
///
/// Throws:
///
/// - `ColumnNotFoundError` : If the specified column name does not exist in the
/// DataFrame
/// - `IndexOutOfBounds` : If the row index is out of range
///
/// ### Example:
///
/// ```moonbit
/// let df = DataFrame::new!([
///   Series::new("A", SeriesData::Int([1, 2, 3])),
///   Series::new("B", SeriesData::Float([1.5, 2.0, 3.5])),
/// ])
/// df.item!(1, ColumnSelector::Str("A"))
/// df.item!(0, ColumnSelector::Int(1))
/// ```
pub fn DataFrame::item(
  self : DataFrame,
  row : Int,
  column : ColumnSelector
) -> DType!Error {
  let col = match column {
    ColumnSelector::Int(value) => value
    ColumnSelector::Str(value) =>
      match self.index.get(value) {
        Some(idx) => idx
        None => raise ColumnNotFoundError("Column '\{value}' not found")
      }
  }
  if row < 0 || row >= self.shape()[0] {
    raise IndexOutOfBounds("Row index out of bounds")
  }
  self.data[col][row]
}

///|
/// Creates a new DataFrame containing only the first N rows of the original
/// DataFrame. If N is larger than the number of rows in the DataFrame, returns a
/// DataFrame with all rows from the original DataFrame.
///
/// ### Parameters:
///
/// - `self` : The DataFrame to limit.
/// - `n` : The maximum number of rows to include in the new DataFrame.
///
/// ### Return:
/// 
/// Return a new DataFrame containing at most N rows from the original
/// DataFrame.
///
/// Throws an error of type `Error` if creating the new DataFrame fails.
///
/// ### Example:
///
/// ```moonbit
/// let df = DataFrame::new!([
///   Series::new("A", SeriesData::Int([1, 2, 3, 4, 5])),
///   Series::new("B", SeriesData::Float([1.1, 2.2, 3.3, 4.4, 5.5])),
/// ])
/// let limited = df.limit!(3)
/// ```
pub fn limit(self : DataFrame, n : Int) -> DataFrame!Error {
  let data : Array[Series] = []
  let n = @math.minimum(n, self.shape()[0])
  for series in self.data {
    let new_data = match series.data {
      SeriesData::Int(data) => SeriesData::Int(data.split_at(n).0)
      SeriesData::Float(data) => SeriesData::Float(data.split_at(n).0)
      SeriesData::Bool(data) => SeriesData::Bool(data.split_at(n).0)
      SeriesData::Str(data) => SeriesData::Str(data.split_at(n).0)
    }
    data.push(Series::new(series.name, new_data))
  }
  DataFrame::new!(data)
}

///|
/// Creates a new DataFrame containing only the last N rows of the original
/// DataFrame. If N is larger than the number of rows in the DataFrame, returns a
/// DataFrame with all rows from the original DataFrame.
///
/// ### Parameters:
///
/// - `self` : The DataFrame to extract rows from.
/// - `n` : The number of rows to include from the end of the DataFrame.
///
/// ### Return:
/// 
/// Returns a new DataFrame containing at most N rows from the end of the
/// original DataFrame.
///
/// Throws an error of type `Error` if creating the new DataFrame fails.
///
/// ### Example:
///
/// ```moonbit
/// let df = DataFrame::new!([
///   Series::new("A", SeriesData::Int([1, 2, 3, 4, 5])),
///   Series::new("B", SeriesData::Float([1.1, 2.2, 3.3, 4.4, 5.5])),
/// ])
/// let last_three = df.tail!(3)
/// ```
pub fn tail(self : DataFrame, n : Int) -> DataFrame!Error {
  let data : Array[Series] = []
  let n = @math.minimum(n, self.shape()[0])
  for series in self.data {
    let new_data = match series.data {
      SeriesData::Int(data) =>
        SeriesData::Int(data.split_at(data.length() - n).1)
      SeriesData::Float(data) =>
        SeriesData::Float(data.split_at(data.length() - n).1)
      SeriesData::Bool(data) =>
        SeriesData::Bool(data.split_at(data.length() - n).1)
      SeriesData::Str(data) =>
        SeriesData::Str(data.split_at(data.length() - n).1)
    }
    data.push(Series::new(series.name, new_data))
  }
  DataFrame::new!(data)
}

///| Tests
test "new" {
  let df = DataFrame::new!([
    Series::new("A", SeriesData::Int([1, 2, 3, 4, 5, 6])),
    Series::new("B", SeriesData::Float([1.5, 2.0, 3.5, 4.0, 5.5, 6.0])),
    Series::new("C", SeriesData::Bool([true, false, true, false, true, false])),
    Series::new("D", SeriesData::Str(["a", "b", "c", "d", "e", "f"])),
  ])
  inspect!(df.shape(), content="[6, 4]")
}

test "add_drop_rename" {
  let df = DataFrame::new!([
    Series::new("A", SeriesData::Int([1, 2, 3, 4, 5, 6])),
    Series::new("B", SeriesData::Float([1.5, 2.0, 3.5, 4.0, 5.5, 6.0])),
    Series::new("C", SeriesData::Bool([true, false, true, false, true, false])),
    Series::new("D", SeriesData::Str(["a", "b", "c", "d", "e", "f"])),
  ])
  df.add_column!(Series::new("E", SeriesData::Int([7, 8, 9, 10, 11, 12])))
  inspect!(df.shape(), content="[6, 5]")
  df.drop_column!("E")
  inspect!(df.shape(), content="[6, 4]")
  df.rename!("A", "A1")
  inspect!(df.data()[0].name(), content="A1")
  df.drop_row!(0)
  df.add_row!([
    DType::Int(7),
    DType::Float(7.5),
    DType::Bool(true),
    DType::Str("g"),
  ])
  inspect!(df.shape(), content="[6, 4]")
}

test "select" {
  let df = DataFrame::new!([
    Series::new("A", SeriesData::Int([1, 2, 3, 4, 5, 6])),
    Series::new("B", SeriesData::Float([1.5, 2.0, 3.5, 4.0, 5.5, 6.0])),
    Series::new("C", SeriesData::Bool([true, false, true, false, true, false])),
    Series::new("D", SeriesData::Str(["a", "b", "c", "d", "e", "f"])),
  ])
  let col_selected = df.select_columns!(["A", "B"])
  inspect!(col_selected.shape(), content="[6, 2]")
  let row_selected = df.select_rows!(range=(1, 3))
  inspect!(row_selected.shape(), content="[2, 4]")
  let row_selected = df.select_rows!(indices=[1, 3, 5])
  inspect!(row_selected.shape(), content="[3, 4]")
}

test "filter" {
  let df = DataFrame::new!([
    Series::new("A", SeriesData::Int([1, 1, 3, 1, 1, 6])),
    Series::new("B", SeriesData::Float([1.5, 2.0, 3.5, 4.0, 5.5, 6.0])),
    Series::new("C", SeriesData::Bool([true, false, true, false, true, false])),
    Series::new("D", SeriesData::Str(["a", "b", "c", "d", "e", "f"])),
  ])
  let filtered = df.filter!("A", fn(x) -> Bool { x < DType::Int(3) })
  inspect!(filtered.shape(), content="[4, 4]")
}

test "sort" {
  let df = DataFrame::new!([
    Series::new("A", SeriesData::Int([2, 1, 3, 5, 4])),
    Series::new("B", SeriesData::Float([2.2, 1.1, 3.3, 5.5, 4.4])),
    Series::new("C", SeriesData::Bool([true, false, true, false, true])),
    Series::new("D", SeriesData::Str(["b", "a", "c", "e", "d"])),
  ])
  df.sort!("A")
  inspect!(df.data()[0].data(), content="Int([1, 2, 3, 4, 5])")
  df.sort!("A", descending=true)
  inspect!(df.data()[0].data(), content="Int([5, 4, 3, 2, 1])")
  inspect!(
    df.data()[3].data(),
    content="Str([\"e\", \"d\", \"c\", \"b\", \"a\"])",
  )
}

///|
test "new_error" {
  let col1 = Series::new("A", SeriesData::Int([1, 2, 3, 4, 5, 6]))
  let col2 = Series::new("B", SeriesData::Float([1.5, 2.0, 3.5]))
  let res = DataFrame::new?([col1, col2])
  inspect!(
    res,
    content="Err(InconsistentSeriesLength(\"Could not create a new DataFrame. The Series lengths are not equal.\"))",
  )
}

test "add_column_error" {
  let df = DataFrame::new!([
    Series::new("A", SeriesData::Int([1, 2, 3, 4, 5, 6])),
    Series::new("B", SeriesData::Float([1.5, 2.0, 3.5, 4.0, 5.5, 6.0])),
  ])
  let col = Series::new("B", SeriesData::Int([1, 2, 3, 4, 5, 6]))
  let res = df.add_column?(col)
  inspect!(
    res,
    content="Err(DuplicateColumnError(\"Could not add a new column to the DataFrame. The Series name already exists.\"))",
  )
  let res = df.add_column?(Series::new("C", SeriesData::Int([1, 2, 3])))
  inspect!(
    res,
    content="Err(InconsistentSeriesLength(\"Could not add a new column to the DataFrame. The Series lengths are not equal.\"))",
  )
}

test "drop_column_error" {
  let df = DataFrame::new!([
    Series::new("A", SeriesData::Int([1, 2, 3, 4, 5, 6])),
    Series::new("B", SeriesData::Float([1.5, 2.0, 3.5, 4.0, 5.5, 6.0])),
  ])
  let res = df.drop_column?("C")
  inspect!(res, content="Err(ColumnNotFoundError(\"Column 'C' not found\"))")
}

test "rename_column_error" {
  let df = DataFrame::new!([
    Series::new("A", SeriesData::Int([1, 2, 3, 4, 5, 6])),
    Series::new("B", SeriesData::Float([1.5, 2.0, 3.5, 4.0, 5.5, 6.0])),
  ])
  let res = df.rename?("C", "D")
  inspect!(res, content="Err(ColumnNotFoundError(\"Column 'C' not found\"))")
}

test "vstack" {
  let df1 = DataFrame::new!([
    Series::new("A", SeriesData::Int([1, 2, 3])),
    Series::new("B", SeriesData::Str(["a", "b", "c"])),
  ])
  let df2 = DataFrame::new!([
    Series::new("A", SeriesData::Int([4, 5, 6])),
    Series::new("B", SeriesData::Str(["d", "e", "f"])),
  ])
  let res = df1.vstack!(df2)
  inspect!(res.shape(), content="[6, 2]")
  inspect!(res.data()[0].data(), content="Int([1, 2, 3, 4, 5, 6])")
  inspect!(
    res.data()[1].data(),
    content="Str([\"a\", \"b\", \"c\", \"d\", \"e\", \"f\"])",
  )
}

test "hstack" {
  let df1 = DataFrame::new!([
    Series::new("A", SeriesData::Int([1, 2, 3])),
    Series::new("B", SeriesData::Str(["a", "b", "c"])),
  ])
  let df2 = DataFrame::new!([
    Series::new("A", SeriesData::Int([4, 5, 6])),
    Series::new("C", SeriesData::Str(["d", "e", "f"])),
  ])
  let res = df1.hstack!(df2)
  inspect!(res.shape(), content="[3, 3]")
  inspect!(res.column!("A"), content="{name: \"A\", data: Int([4, 5, 6])}")
  inspect!(
    res.column!("B"),
    content="{name: \"B\", data: Str([\"a\", \"b\", \"c\"])}",
  )
  inspect!(
    res.column!("C"),
    content="{name: \"C\", data: Str([\"d\", \"e\", \"f\"])}",
  )
}
