IF COL_LENGTH('dbo.Customer','Notes') IS NULL
    THROW 51012, 'Additive upgrade column is missing.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.Customer WHERE ExternalId='11111111-1111-1111-1111-111111111111' AND DisplayName=N'Existing customer longer than ten characters')
    THROW 51013, 'Existing data was changed or lost.', 1;
IF COL_LENGTH('dbo.Customer','DisplayName') <> 400
    THROW 51014, 'Unsafe narrowing changed the column.', 1;
