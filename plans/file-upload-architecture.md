# Архитектура загрузки файлов (ActiveStorage)

## Обзор

Сейчас картинки задаются через URL (`image_url`). Нужно добавить возможность загружать файлы с компьютера.

## Решение: ActiveStorage

Rails ActiveStorage — встроенное решение для загрузки файлов.

### Бэкенд

1. **Установка:**
   ```bash
   rails active_storage:install
   rails db:migrate
   ```
   Создаст таблицы: `active_storage_blobs`, `active_storage_attachments`, `active_storage_variant_records`

2. **Модели — добавить `has_one_attached`:**
   ```ruby
   # MenuItem
   has_one_attached :image

   # Category
   has_one_attached :image

   # MenuItemGroup
   has_one_attached :image
   ```

3. **Сериализаторы — добавить URL картинки:**
   ```ruby
   # В as_json
   image_url: @menu_item.image.attached? ? url_for(@menu_item.image) : @menu_item.image_url
   ```
   - Если файл загружен → отдаём URL из ActiveStorage
   - Если нет → fallback на `image_url` (старое поле)

4. **Контроллеры — поддержка multipart/form-data:**
   ```ruby
   def menu_item_params
     params.require(:menu_item).permit(..., :image)
   end
   ```
   `:image` — это загружаемый файл, передаётся как `FormData` с ключом `menu_item[image]`

5. **Хранение:**
   - Development: `:local` (диск в `storage/`)
   - Production: `:s3` (AWS S3) или `:gcs` (Google Cloud Storage)
   - Настройка в `config/storage.yml`

### Админка (React)

6. **Компонент ImageUpload:**
   ```tsx
   <input type="file" accept="image/*" onChange={handleFile} />
   {preview && <img src={preview} />}
   ```

7. **Отправка через FormData:**
   ```ts
   const formData = new FormData()
   formData.append('menu_item[name]', name)
   formData.append('menu_item[image]', file)
   // ... остальные поля
   api.post('/menu_items', formData, { headers: { 'Content-Type': 'multipart/form-data' } })
   ```

8. **Где заменить URL на файл:**
   - MenuItemsPage — форма создания/редактирования
   - CategoriesPage — форма создания/редактирования
   - MenuItemGroupsPage — форма создания/редактирования

### Клиентский фронтенд

9. **Изменений не требуется** — API отдаёт `image_url` в любом случае (либо ActiveStorage URL, либо старый URL)

### План миграции

- Старое поле `image_url` НЕ удаляем — оно остаётся как fallback
- При загрузке файла через ActiveStorage — `image_url` игнорируется
- Если файл не загружен — используется `image_url`

### Порядок реализации

1. `rails active_storage:install` + миграция
2. Добавить `has_one_attached :image` в модели
3. Обновить сериализаторы
4. Обновить контроллеры (permit :image)
5. Создать ImageUpload компонент в админке
6. Заменить Input (URL) на ImageUpload в формах
7. Тесты